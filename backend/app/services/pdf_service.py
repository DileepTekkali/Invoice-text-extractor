import base64
import fitz
import json
import os
import re
from groq import Groq

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

TEXT_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"
VISION_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"
MAX_TEXT_CHARS = 24000
MAX_HINT_TEXT_CHARS = 6000
MAX_VISION_PAGES = 6
PDF_HEADER_WINDOW = 1024
MIN_MEANINGFUL_TEXT_LENGTH = 20

IMAGE_SIGNATURES = {
    b"\x89PNG\r\n\x1a\n": "image/png",
    b"\xff\xd8\xff": "image/jpeg",
}

IMAGE_EXTENSIONS = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
}

INVOICE_PROMPT = """You extract structured data from invoice-like commercial documents.

Treat all of the following as valid invoice-like inputs when they contain billing or payment details:
- invoice
- tax invoice
- GST invoice / GST bill
- retail bill / bill / cash bill / cash memo
- vendor bill / purchase invoice
- pro forma invoice
- receipt or payment receipt when it contains seller, buyer, amount, or item details

Rules:
1. Use only content visible in the provided document text or images. Do not invent values.
2. Do not reject a document only because the title says Bill, Receipt, Tax Invoice, Cash Memo, or Estimate instead of Invoice.
3. Use context, layout, and nearby labels to classify fields. Labels may vary.
4. Capture seller, customer, invoice numbers, dates, totals, taxes, and payment details whenever visible.
5. Extract all line items you can reliably identify. Preserve multi-line descriptions.
6. If the document is a receipt without line items, keep line_items as an empty array.
7. Normalize dates to YYYY-MM-DD only when unambiguous. Otherwise keep the original string.
8. Numeric fields must be numbers, not strings. Remove currency symbols and thousands separators.
9. Missing values must be null, not fabricated placeholders.
10. Multiple invoices in one document must be returned as multiple objects in the invoices array.
11. Handle OCR noise conservatively. Prefer null over a guessed value.
12. Return only valid JSON. No markdown. No explanations.

Return JSON with exactly this top-level structure:
{
  "invoices": [
    {
      "invoice_metadata": {
        "invoice_number": null,
        "invoice_date": null,
        "submitted_date": null,
        "due_date": null,
        "status": null,
        "currency": null
      },
      "seller_business": {
        "business_name": null,
        "business_address": null,
        "owner_name": null,
        "mobile_number": null,
        "phone_number": null,
        "email": null,
        "gst_number": null,
        "tax_id": null,
        "pan": null,
        "website": null
      },
      "customer": {
        "customer_name": null,
        "customer_address": null,
        "phone_number": null,
        "email": null,
        "gst_number": null
      },
      "payment_info": {
        "payment_method": null,
        "bank_name": null,
        "account_number": null,
        "account_holder_name": null,
        "ifsc_code": null,
        "upi_id": null,
        "branch_name": null
      },
      "line_items": [
        {
          "item_number": null,
          "description": null,
          "hsn_sac": null,
          "quantity": null,
          "unit": null,
          "rate": null,
          "amount": null,
          "tax_rate": null
        }
      ],
      "financial_summary": {
        "subtotal": null,
        "tax": null,
        "tax_breakdown": {
          "cgst": null,
          "sgst": null,
          "igst": null,
          "gst": null
        },
        "discount": null,
        "total_amount": null
      },
      "additional_details": {
        "notes": null,
        "terms_and_conditions": null,
        "shipping_address": null,
        "vehicle_number": null,
        "transport_name": null,
        "place_of_supply": null
      }
    }
  ]
}"""


def is_likely_pdf(file_bytes):
    if not file_bytes:
        return False
    header = file_bytes[:PDF_HEADER_WINDOW]
    return b"%PDF-" in header


def is_supported_image(file_bytes, filename=""):
    return _guess_image_mime_type(file_bytes, filename) is not None


def has_meaningful_extraction(structured_data):
    if not isinstance(structured_data, dict):
        return False
    return _has_structured_signal(structured_data) or _has_meaningful_text(
        structured_data.get("full_text", "")
    )


def extract_structured_data_from_pdf(file_bytes, debug_dir=None):
    doc = None
    try:
        doc = fitz.open(stream=file_bytes, filetype="pdf")
        all_text, text_metadata = _extract_text_from_pdf(doc)

        text_result = None
        text_error = None

        if _has_meaningful_text(all_text):
            text_result = extract_with_groq(all_text)
            if _has_structured_signal(text_result):
                text_result.setdefault("metadata", {}).update(
                    {
                        **text_metadata,
                        "source_type": "pdf",
                        "fallback_used": False,
                    }
                )
                return text_result
            text_error = text_result.get("error")

        vision_result = None
        if len(doc) > 0:
            rendered_pages = _render_pdf_pages(doc, debug_dir=debug_dir)
            if rendered_pages:
                vision_result = extract_with_groq_vision(
                    rendered_pages,
                    source_label="pdf",
                    raw_text_hint=all_text,
                )
                if _has_structured_signal(vision_result):
                    if not vision_result.get("full_text"):
                        vision_result["full_text"] = all_text
                    vision_result.setdefault("metadata", {}).update(
                        {
                            **text_metadata,
                            "source_type": "pdf",
                            "fallback_used": True,
                        }
                    )
                    return vision_result

        if _has_meaningful_text(all_text):
            return _build_raw_text_response(
                full_text=all_text,
                extraction_method="pdf_text_fallback",
                extra_metadata={
                    **text_metadata,
                    "source_type": "pdf",
                    "fallback_used": bool(vision_result),
                },
                warning=text_error or "Structured parsing did not return reliable invoice fields.",
            )

        error_message = "The file is a valid PDF, but no readable invoice text could be extracted."
        if vision_result and vision_result.get("error"):
            error_message = vision_result["error"]

        return _empty_response(
            full_text="",
            error=error_message,
            extraction_method="pdf_unreadable",
            extra_metadata={**text_metadata, "source_type": "pdf"},
        )
    except Exception as e:
        return _empty_response(
            full_text="",
            error=str(e),
            extraction_method="pdf_error",
            extra_metadata={"source_type": "pdf"},
        )
    finally:
        if doc is not None:
            doc.close()


def extract_structured_data_from_image(file_bytes, filename="invoice-image"):
    try:
        mime_type = _guess_image_mime_type(file_bytes, filename)
        if not mime_type:
            return _empty_response(
                full_text="",
                error="Unsupported image format. Please upload PNG, JPG, JPEG, or WEBP.",
                extraction_method="image_invalid",
                extra_metadata={"source_type": "image"},
            )

        vision_result = extract_with_groq_vision(
            [
                {
                    "name": filename,
                    "mime_type": mime_type,
                    "bytes": file_bytes,
                }
            ],
            source_label="image",
        )

        if _has_structured_signal(vision_result):
            vision_result.setdefault("metadata", {}).update(
                {"source_type": "image", "fallback_used": False}
            )
            return vision_result

        return _empty_response(
            full_text=vision_result.get("full_text", ""),
            error=vision_result.get("error")
            or "The image was uploaded, but invoice details could not be extracted.",
            extraction_method="image_unreadable",
            extra_metadata={"source_type": "image"},
        )
    except Exception as e:
        return _empty_response(
            full_text="",
            error=str(e),
            extraction_method="image_error",
            extra_metadata={"source_type": "image"},
        )


def extract_with_groq(text):
    try:
        client = _get_client()
        prompt = f"{INVOICE_PROMPT}\n\nDOCUMENT TEXT:\n{text[:MAX_TEXT_CHARS]}"

        response = client.chat.completions.create(
            model=TEXT_MODEL,
            response_format={"type": "json_object"},
            messages=[
                {
                    "role": "system",
                    "content": "Return only valid JSON matching the requested schema.",
                },
                {"role": "user", "content": prompt},
            ],
            temperature=0,
            max_tokens=8000,
        )

        parsed = _parse_response_json(response.choices[0].message.content)
        return _build_structured_response(
            parsed,
            full_text=text,
            extraction_method="groq_text",
        )
    except json.JSONDecodeError as e:
        return _empty_response(
            full_text=text,
            error=f"Failed to parse model response as JSON: {e}",
            extraction_method="groq_text_parse_error",
        )
    except Exception as e:
        return _empty_response(
            full_text=text,
            error=f"Groq text extraction failed: {e}",
            extraction_method="groq_text_error",
        )


def extract_with_groq_vision(images, source_label="document", raw_text_hint=""):
    try:
        client = _get_client()

        instructions = [
            INVOICE_PROMPT,
            "",
            f"DOCUMENT SOURCE: {source_label}",
            "Use the images as the primary source of truth.",
        ]

        if raw_text_hint and raw_text_hint.strip():
            instructions.extend(
                [
                    "",
                    "PARTIAL MACHINE-READABLE TEXT HINT:",
                    raw_text_hint[:MAX_HINT_TEXT_CHARS],
                    "",
                    "Use the text hint only to resolve OCR ambiguity. Do not duplicate or invent fields.",
                ]
            )

        content = [{"type": "text", "text": "\n".join(instructions)}]
        for image in images[:MAX_VISION_PAGES]:
            content.append(
                {
                    "type": "image_url",
                    "image_url": {
                        "url": _to_data_url(image["bytes"], image["mime_type"]),
                        "detail": "high",
                    },
                }
            )

        response = client.chat.completions.create(
            model=VISION_MODEL,
            response_format={"type": "json_object"},
            messages=[
                {
                    "role": "system",
                    "content": "Return only valid JSON matching the requested schema.",
                },
                {"role": "user", "content": content},
            ],
            temperature=0,
            max_tokens=8000,
        )

        parsed = _parse_response_json(response.choices[0].message.content)
        return _build_structured_response(
            parsed,
            full_text=raw_text_hint,
            extraction_method=f"groq_vision_{source_label}",
        )
    except json.JSONDecodeError as e:
        return _empty_response(
            full_text=raw_text_hint,
            error=f"Failed to parse vision response as JSON: {e}",
            extraction_method=f"groq_vision_{source_label}_parse_error",
        )
    except Exception as e:
        return _empty_response(
            full_text=raw_text_hint,
            error=f"Groq vision extraction failed: {e}",
            extraction_method=f"groq_vision_{source_label}_error",
        )


def _get_client():
    return Groq(api_key=GROQ_API_KEY)


def _extract_text_from_pdf(doc):
    page_text_chunks = []
    direct_text_pages = 0

    for page_number, page in enumerate(doc, start=1):
        page_text = _clean_text(page.get_text("text", sort=True))

        if not page_text:
            blocks = page.get_text("blocks", sort=True)
            block_text = "\n".join(
                _clean_text(block[4]) for block in blocks if len(block) > 4 and _clean_text(block[4])
            )
            page_text = _clean_text(block_text)

        if page_text:
            direct_text_pages += 1
            page_text_chunks.append(f"[PAGE {page_number}]\n{page_text}")

    return "\n\n".join(page_text_chunks).strip(), {
        "page_count": len(doc),
        "direct_text_pages": direct_text_pages,
    }


def _render_pdf_pages(doc, debug_dir=None):
    rendered_pages = []

    for page_number, page in enumerate(doc, start=1):
        if page_number > MAX_VISION_PAGES:
            break

        pix = page.get_pixmap(matrix=fitz.Matrix(1.5, 1.5), alpha=False)
        image_bytes = pix.tobytes("png")
        rendered_pages.append(
            {
                "name": f"page-{page_number}.png",
                "mime_type": "image/png",
                "bytes": image_bytes,
            }
        )

        if debug_dir:
            os.makedirs(debug_dir, exist_ok=True)
            with open(os.path.join(debug_dir, f"debug_page_{page_number}.png"), "wb") as f:
                f.write(image_bytes)

    return rendered_pages


def _parse_response_json(result_text):
    if not isinstance(result_text, str):
        raise json.JSONDecodeError("Model response was not a string", "", 0)

    cleaned = result_text.strip()
    if cleaned.startswith("```json"):
        cleaned = cleaned[7:]
    if cleaned.startswith("```"):
        cleaned = cleaned[3:]
    if cleaned.endswith("```"):
        cleaned = cleaned[:-3]
    cleaned = cleaned.strip()

    return json.loads(cleaned)


def _build_structured_response(parsed, full_text, extraction_method):
    invoices = _normalize_invoices(parsed)

    tables = []
    line_items = []

    for inv in invoices:
        invoice_items = inv.get("line_items") or []
        line_items.extend(invoice_items)

        if invoice_items:
            headers = ["Item #", "Description", "Qty", "Unit", "Rate", "Amount", "Tax Rate"]
            rows = []
            for item in invoice_items:
                rows.append(
                    [
                        _stringify_value(item.get("item_number")),
                        _stringify_value(item.get("description")),
                        _stringify_value(item.get("quantity")),
                        _stringify_value(item.get("unit")),
                        _stringify_value(item.get("rate")),
                        _stringify_value(item.get("amount")),
                        _stringify_value(item.get("tax_rate")),
                    ]
                )
            if rows:
                tables.append(
                    {
                        "table_name": "Line Items",
                        "headers": headers,
                        "rows": rows,
                    }
                )

    first_invoice = invoices[0] if invoices else {}
    meta = first_invoice.get("invoice_metadata", {})
    seller = first_invoice.get("seller_business", {})
    customer = first_invoice.get("customer", {})
    payment = first_invoice.get("payment_info", {})
    financial = first_invoice.get("financial_summary", {})
    additional = first_invoice.get("additional_details", {})

    total_amount = _number_or_zero(financial.get("total_amount"))

    header_fields = {
        "invoice_number": _string_or_empty(meta.get("invoice_number")),
        "date": _string_or_empty(meta.get("invoice_date")),
        "due_date": _string_or_empty(meta.get("due_date")),
        "total": total_amount,
        "total_amount": total_amount,
        "currency": _string_or_empty(meta.get("currency")),
        "business_name": _string_or_empty(seller.get("business_name")),
        "customer_name": _string_or_empty(customer.get("customer_name")),
        "email": _string_or_empty(seller.get("email") or customer.get("email")),
        "phone": _string_or_empty(
            seller.get("phone_number")
            or seller.get("mobile_number")
            or customer.get("phone_number")
        ),
        "address": _string_or_empty(
            seller.get("business_address") or customer.get("customer_address")
        ),
    }

    return {
        "full_text": full_text,
        "invoices": invoices,
        "tables": tables,
        "line_items": line_items,
        "header_fields": header_fields,
        "subtotal": _number_or_zero(financial.get("subtotal")),
        "tax": _number_or_zero(financial.get("tax")),
        "discount": _number_or_zero(financial.get("discount")),
        "total_due": total_amount,
        "extra_fields": {
            "payment_info": payment,
            "additional_details": additional,
            "gst_number": _string_or_empty(seller.get("gst_number")),
            "pan": _string_or_empty(seller.get("pan")),
        },
        "metadata": {"extraction_method": extraction_method},
        "table_count": len(tables),
    }


def _build_raw_text_response(
    full_text,
    extraction_method,
    extra_metadata=None,
    warning=None,
):
    response = {
        "full_text": full_text,
        "invoices": [],
        "tables": [],
        "line_items": [],
        "header_fields": {},
        "subtotal": 0,
        "tax": 0,
        "discount": 0,
        "total_due": 0,
        "extra_fields": {},
        "metadata": {"extraction_method": extraction_method},
        "table_count": 0,
    }

    if extra_metadata:
        response["metadata"].update(extra_metadata)
    if warning:
        response["warning"] = warning

    return response


def _empty_response(
    full_text="",
    error="",
    extraction_method="unknown",
    extra_metadata=None,
):
    response = {
        "full_text": full_text,
        "invoices": [],
        "tables": [],
        "line_items": [],
        "header_fields": {},
        "subtotal": 0,
        "tax": 0,
        "discount": 0,
        "total_due": 0,
        "extra_fields": {},
        "metadata": {"extraction_method": extraction_method},
        "table_count": 0,
    }

    if extra_metadata:
        response["metadata"].update(extra_metadata)
    if error:
        response["error"] = error

    return response


def _normalize_invoices(parsed):
    if isinstance(parsed, dict):
        invoices = parsed.get("invoices")
        if isinstance(invoices, list):
            return invoices

        if any(
            key in parsed
            for key in (
                "invoice_metadata",
                "seller_business",
                "customer",
                "financial_summary",
            )
        ):
            return [parsed]

    return []


def _has_structured_signal(structured_data):
    if not isinstance(structured_data, dict):
        return False

    if structured_data.get("invoices"):
        return True

    if structured_data.get("line_items"):
        return True

    header_fields = structured_data.get("header_fields") or {}
    return any(_has_value(value) for value in header_fields.values())


def _has_meaningful_text(text):
    return isinstance(text, str) and len(text.strip()) >= MIN_MEANINGFUL_TEXT_LENGTH


def _has_value(value):
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, (list, dict)):
        return bool(value)
    return True


def _guess_image_mime_type(file_bytes, filename=""):
    if not file_bytes:
        return None

    for signature, mime_type in IMAGE_SIGNATURES.items():
        if file_bytes.startswith(signature):
            return mime_type

    if file_bytes.startswith(b"RIFF") and file_bytes[8:12] == b"WEBP":
        return "image/webp"

    ext = os.path.splitext((filename or "").lower())[1]
    return IMAGE_EXTENSIONS.get(ext)


def _to_data_url(file_bytes, mime_type):
    encoded = base64.b64encode(file_bytes).decode("ascii")
    return f"data:{mime_type};base64,{encoded}"


def _clean_text(text):
    if not text:
        return ""
    text = text.replace("\x00", " ")
    text = re.sub(r"\r\n?", "\n", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _stringify_value(value):
    if value is None:
        return ""
    return str(value)


def _string_or_empty(value):
    if value is None:
        return ""
    return str(value).strip()


def _number_or_zero(value):
    if isinstance(value, (int, float)):
        return value
    if value is None:
        return 0

    cleaned = str(value).strip()
    if not cleaned:
        return 0

    cleaned = cleaned.replace(",", "")
    try:
        return float(cleaned)
    except ValueError:
        return 0


def format_extracted_data(structured_data):
    if "error" in structured_data:
        return f"Error: {structured_data['error']}\n\n--- RAW TEXT ---\n{structured_data.get('full_text', '')}"
    
    parts = []
    
    invoices = structured_data.get("invoices", [])
    if invoices:
        parts.append("=== INVOICES START ===")
        
        for idx, inv in enumerate(invoices, 1):
            parts.append(f"\n--- INVOICE {idx} START ---")
            
            meta = inv.get("invoice_metadata", {})
            parts.append("\n[INVOICE METADATA]")
            for k, v in meta.items():
                if v:
                    parts.append(f"{k.upper()}: {v}")
            
            seller = inv.get("seller_business", {})
            if seller:
                parts.append("\n[SELLER BUSINESS]")
                for k, v in seller.items():
                    if v:
                        parts.append(f"{k.upper()}: {v}")
            
            customer = inv.get("customer", {})
            if customer:
                parts.append("\n[CUSTOMER]")
                for k, v in customer.items():
                    if v:
                        parts.append(f"{k.upper()}: {v}")
            
            payment = inv.get("payment_info", {})
            if payment:
                parts.append("\n[PAYMENT INFO]")
                for k, v in payment.items():
                    if v:
                        parts.append(f"{k.upper()}: {v}")
            
            financial = inv.get("financial_summary", {})
            if financial:
                parts.append("\n[FINANCIAL SUMMARY]")
                for k, v in financial.items():
                    if k == "tax_breakdown" and isinstance(v, dict):
                        parts.append("TAX_BREAKDOWN:")
                        for tk, tv in v.items():
                            parts.append(f"  {tk.upper()}: {tv}")
                    elif v:
                        parts.append(f"{k.upper()}: {v}")
            
            additional = inv.get("additional_details", {})
            if additional:
                parts.append("\n[ADDITIONAL DETAILS]")
                for k, v in additional.items():
                    if v:
                        parts.append(f"{k.upper()}: {v}")
            
            line_items = inv.get("line_items", [])
            if line_items:
                parts.append("\n[LINE ITEMS]")
                parts.append("HEADERS:Item #|Description|Qty|Unit|Rate|Amount|Tax Rate")
                for item in line_items:
                    parts.append(f"ROW:{item.get('item_number', '')}|{item.get('description', '')}|{item.get('quantity', 0)}|{item.get('unit', '')}|{item.get('rate', 0)}|{item.get('amount', 0)}|{item.get('tax_rate', '')}")
            
            parts.append(f"\n--- INVOICE {idx} END ---")
        
        parts.append("=== INVOICES END ===")
    
    return "\n".join(parts)
