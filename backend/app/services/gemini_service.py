import base64
import json
import os
from pathlib import Path
from typing import Any

import requests


class GeminiService:
    def __init__(self, api_key: str | None = None):
        self.api_key = (
            api_key
            or os.environ.get("GEMINI_API_KEY", "")
            or os.environ.get("GOOGLE_API_KEY", "")
            or self._read_env_value("GEMINI_API_KEY")
            or self._read_env_value("GOOGLE_API_KEY")
        ).strip()
        self.model = self._normalize_model_name(
            os.environ.get("GEMINI_MODEL", "")
            or self._read_env_value("GEMINI_MODEL")
            or "gemini-2.5-flash"
        )
        self.session = requests.Session()
        self.base_url = "https://generativelanguage.googleapis.com/v1beta"
        self.timeout = 30

    def is_configured(self) -> bool:
        return bool(self.api_key)

    def verify_connection(self) -> dict[str, Any]:
        if not self.is_configured():
            return {
                "ok": False,
                "message": "GEMINI_API_KEY is not configured.",
                "models": [],
            }

        try:
            response = self.session.get(
                f"{self.base_url}/models",
                params={"key": self.api_key},
                timeout=15,
            )
            payload = self._parse_response_json(response)
            if not response.ok:
                return {
                    "ok": False,
                    "message": self._extract_error_message(payload),
                    "models": [],
                }

            model_ids = [
                model.get("name", "")
                for model in payload.get("models", [])[:5]
                if isinstance(model, dict)
            ]
            return {
                "ok": True,
                "message": "Gemini API key is valid.",
                "models": model_ids,
            }
        except Exception as exc:
            return {
                "ok": False,
                "message": f"Gemini API verification failed: {exc}",
                "models": [],
            }

    def extract_invoice_data(
        self,
        file_bytes: bytes,
        filename: str,
        mime_type: str = "image/png",
    ) -> dict[str, Any]:
        if not self.is_configured():
            return self._get_empty_invoice_data()

        try:
            prompt = self._build_image_prompt(filename)
            response_text = self._generate_json_response(
                parts=[
                    {"text": prompt},
                    {
                        "inlineData": {
                            "mimeType": mime_type,
                            "data": base64.b64encode(file_bytes).decode("utf-8"),
                        }
                    },
                ],
            )
            invoice_data = json.loads(response_text)
            return self._normalize_invoice_data(invoice_data)
        except json.JSONDecodeError as exc:
            print(f"JSON parsing error: {exc}")
            print(
                "Raw response: "
                f"{response_text[:500] if 'response_text' in locals() else 'N/A'}"
            )
            return self._get_empty_invoice_data()
        except Exception as exc:
            print(f"Gemini API error: {exc}")
            import traceback

            traceback.print_exc()
            return self._get_empty_invoice_data()

    def extract_from_text(self, text: str) -> dict[str, Any]:
        if not self.is_configured():
            return self._get_empty_invoice_data()

        try:
            prompt = self._build_text_prompt(text)
            response_text = self._generate_json_response(
                parts=[{"text": prompt}],
            )
            invoice_data = json.loads(response_text)
            return self._normalize_invoice_data(invoice_data)
        except json.JSONDecodeError as exc:
            print(f"JSON parsing error: {exc}")
            print(
                "Raw response: "
                f"{response_text[:500] if 'response_text' in locals() else 'N/A'}"
            )
            return self._get_empty_invoice_data()
        except Exception as exc:
            print(f"Gemini API error: {exc}")
            import traceback

            traceback.print_exc()
            return self._get_empty_invoice_data()

    def _generate_json_response(
        self,
        parts: list[dict[str, Any]],
    ) -> str:
        payload = {
            "generationConfig": {
                "temperature": 0.1,
                "responseMimeType": "application/json",
            },
            "contents": [
                {
                    "role": "user",
                    "parts": parts,
                }
            ],
        }
        response = self.session.post(
            f"{self.base_url}/models/{self.model}:generateContent",
            params={"key": self.api_key},
            json=payload,
            timeout=self.timeout,
        )
        response_data = self._parse_response_json(response)
        if not response.ok:
            raise RuntimeError(self._extract_error_message(response_data))

        candidates = response_data.get("candidates", [])
        if not candidates:
            raise RuntimeError("Gemini returned no candidates.")

        content = candidates[0].get("content", {})
        response_parts = content.get("parts", [])
        response_text = "".join(
            part.get("text", "")
            for part in response_parts
            if isinstance(part, dict) and part.get("text")
        ).strip()

        if not response_text:
            finish_reason = candidates[0].get("finishReason", "unknown")
            raise RuntimeError(
                f"Gemini returned an empty response (finishReason={finish_reason})."
            )

        return self._clean_response_text(response_text)

    def _clean_response_text(self, response_text: str) -> str:
        if response_text.startswith("```json"):
            response_text = response_text[7:]
        if response_text.startswith("```"):
            response_text = response_text[3:]
        if response_text.endswith("```"):
            response_text = response_text[:-3]
        return response_text.strip()

    def _normalize_invoice_data(self, invoice_data: Any) -> dict[str, Any]:
        normalized = self._get_empty_invoice_data()
        if not isinstance(invoice_data, dict):
            return normalized

        for section in (
            "invoice_details",
            "vendor_details",
            "customer_details",
            "payment_details",
            "summary",
            "additional_info",
        ):
            section_value = invoice_data.get(section)
            if isinstance(section_value, dict):
                normalized[section].update(section_value)

        line_items = invoice_data.get("line_items")
        if isinstance(line_items, list):
            normalized["line_items"] = []
            for item in line_items:
                if not isinstance(item, dict):
                    continue
                normalized_item = {
                    "description": "",
                    "quantity": 0,
                    "unit_price": 0,
                    "total": 0,
                }
                normalized_item.update(item)
                normalized["line_items"].append(normalized_item)

        return normalized

    def _parse_response_json(self, response: requests.Response) -> dict[str, Any]:
        try:
            return response.json()
        except ValueError:
            return {"error": {"message": response.text.strip() or "Unknown API error"}}

    def _extract_error_message(self, response_data: dict[str, Any]) -> str:
        error = response_data.get("error", {})
        if isinstance(error, dict):
            message = error.get("message")
            status = error.get("status")
            if message and status:
                return f"{status}: {message}"
            if message:
                return message
        return "Gemini request failed."

    def _build_image_prompt(self, filename: str) -> str:
        return f"""You are an intelligent document parsing system specialized in extracting structured data from invoices.

Analyze the invoice file named "{filename}" and return ONLY valid JSON with this exact structure:

{{
  "invoice_details": {{
    "invoice_number": "",
    "invoice_date": "",
    "due_date": "",
    "currency": ""
  }},
  "vendor_details": {{
    "name": "",
    "address": "",
    "email": "",
    "phone": ""
  }},
  "customer_details": {{
    "name": "",
    "address": "",
    "email": "",
    "phone": ""
  }},
  "payment_details": {{
    "payment_method": "",
    "bank_name": "",
    "account_number": "",
    "account_name": ""
  }},
  "line_items": [
    {{
      "description": "",
      "quantity": 0,
      "unit_price": 0,
      "total": 0
    }}
  ],
  "summary": {{
    "subtotal": 0,
    "tax": 0,
    "discount": 0,
    "total": 0
  }},
  "additional_info": {{
    "notes": "",
    "terms": ""
  }}
}}

Rules:
- Extract only information visible in the invoice.
- Ignore logos, decorative images, watermarks, signatures, and stamps.
- If a field is missing, return null or an empty string instead of inventing data.
- Normalize dates into ISO format when possible.
- Return numeric values without currency symbols.
- Use ISO currency codes when possible, for example INR, USD, EUR, GBP, or JPY.
- Return only JSON, with no markdown fences or explanation."""

    def _build_text_prompt(self, text: str) -> str:
        return f"""You are an intelligent document parsing system specialized in extracting structured data from invoices.

Analyze the following invoice text and return ONLY valid JSON with this exact structure:

{{
  "invoice_details": {{
    "invoice_number": "",
    "invoice_date": "",
    "due_date": "",
    "currency": ""
  }},
  "vendor_details": {{
    "name": "",
    "address": "",
    "email": "",
    "phone": ""
  }},
  "customer_details": {{
    "name": "",
    "address": "",
    "email": "",
    "phone": ""
  }},
  "payment_details": {{
    "payment_method": "",
    "bank_name": "",
    "account_number": "",
    "account_name": ""
  }},
  "line_items": [
    {{
      "description": "",
      "quantity": 0,
      "unit_price": 0,
      "total": 0
    }}
  ],
  "summary": {{
    "subtotal": 0,
    "tax": 0,
    "discount": 0,
    "total": 0
  }},
  "additional_info": {{
    "notes": "",
    "terms": ""
  }}
}}

INVOICE TEXT:
{text}

Rules:
- Extract only what is present in the text.
- If a field is missing, return null or an empty string instead of hallucinating.
- Normalize dates into ISO format when possible.
- Return numeric values without currency symbols.
- Use ISO currency codes when possible, for example INR, USD, EUR, GBP, or JPY.
- Return only JSON, with no markdown fences or explanation."""

    def _get_empty_invoice_data(self) -> dict[str, Any]:
        return {
            "invoice_details": {
                "invoice_number": "",
                "invoice_date": "",
                "due_date": "",
                "currency": "",
            },
            "vendor_details": {
                "name": "",
                "address": "",
                "email": "",
                "phone": "",
            },
            "customer_details": {
                "name": "",
                "address": "",
                "email": "",
                "phone": "",
            },
            "payment_details": {
                "payment_method": "",
                "bank_name": "",
                "account_number": "",
                "account_name": "",
            },
            "line_items": [],
            "summary": {
                "subtotal": 0,
                "tax": 0,
                "discount": 0,
                "total": 0,
            },
            "additional_info": {
                "notes": "",
                "terms": "",
            },
        }

    def _read_env_value(self, key: str) -> str:
        env_path = Path(__file__).resolve().parents[2] / ".env"
        if not env_path.exists():
            return ""

        for raw_line in env_path.read_text().splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            current_key, value = line.split("=", 1)
            if current_key.strip() == key:
                return value.strip().strip("'\"")
        return ""

    def _normalize_model_name(self, model_name: str) -> str:
        normalized = model_name.strip()
        if normalized.startswith("models/"):
            return normalized[7:]
        return normalized


gemini_service = GeminiService()
