from fastapi import APIRouter, UploadFile, File, HTTPException
from app.services.gemini_service import gemini_service

router = APIRouter()
INVALID_INVOICE_DETAIL = (
    "The uploaded file is not a valid invoice. Please upload a proper invoice PDF or image."
)

@router.post("/upload")
async def upload_invoice(file: UploadFile = File(...)):
    try:
        content = await file.read()
        
        if not content or len(content) == 0:
            raise HTTPException(status_code=400, detail="Empty file received")
        
        filename = file.filename or "unknown"
        print(f"Processing file: {filename}, size: {len(content)} bytes")
        
        extraction_method = "ocr"
        invoice_data = gemini_service._get_empty_invoice_data()
        
        from app.services.ocr_service import process_file
        print(f"Starting OCR processing for: {filename}")
        
        try:
            ocr_text = process_file(content, filename)
            print(f"OCR completed. Text length: {len(ocr_text)}")
            print(f"OCR text preview: {ocr_text[:200] if ocr_text else 'EMPTY'}")
        except Exception as ocr_error:
            print(f"OCR processing error: {ocr_error}")
            import traceback
            traceback.print_exc()
            raise HTTPException(
                status_code=500,
                detail=f"Failed to process file: {str(ocr_error)}"
            )
        
        if ocr_text.startswith("NON_INVOICE:"):
            print("Rejected upload because OCR did not detect a valid invoice")
            raise HTTPException(status_code=422, detail=INVALID_INVOICE_DETAIL)

        actual_text = ocr_text.strip()
        
        if not actual_text or len(actual_text.strip()) < 10:
            raise HTTPException(
                status_code=422,
                detail="Could not extract text from the file. Please upload a valid PDF or image."
            )
        
        if gemini_service.is_configured():
            try:
                invoice_data = gemini_service.extract_from_text(actual_text)
                if is_valid_invoice(invoice_data):
                    extraction_method = "gemini"
                    print("Gemini extraction successful")
                else:
                    print("Gemini extraction returned incomplete data, falling back to OCR parsing")
            except Exception as e:
                print(f"Gemini extraction failed: {e}, using OCR text")
        else:
            print("Gemini API key is not configured, using OCR fallback")
        
        if not is_valid_invoice(invoice_data):
            invoice_data = convert_ocr_to_invoice_data(actual_text)

        if not is_valid_invoice(invoice_data):
            raise HTTPException(status_code=422, detail=INVALID_INVOICE_DETAIL)
        
        print(f"Invoice data extracted successfully using {extraction_method}")
        
        return {
            "invoice_data": invoice_data,
            "filename": filename,
            "status": "success",
            "extraction_method": extraction_method,
            "raw_text": actual_text
        }
    
    except HTTPException:
        raise
    except ValueError as e:
        print(f"ValueError: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"Error: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Processing error: {type(e).__name__}: {str(e)}")

def convert_ocr_to_invoice_data(ocr_text: str) -> dict:
    return {
        "invoice_details": {
            "invoice_number": extract_invoice_number(ocr_text),
            "invoice_date": extract_date(ocr_text),
            "due_date": "",
            "currency": extract_currency(ocr_text)
        },
        "vendor_details": {
            "name": extract_vendor_name(ocr_text),
            "address": extract_vendor_address(ocr_text),
            "email": extract_email(ocr_text),
            "phone": extract_phone(ocr_text)
        },
        "customer_details": {
            "name": extract_customer_name(ocr_text),
            "address": "",
            "email": "",
            "phone": ""
        },
        "payment_details": {
            "payment_method": "",
            "bank_name": "",
            "account_number": "",
            "account_name": ""
        },
        "line_items": extract_line_items(ocr_text),
        "summary": {
            "subtotal": extract_subtotal(ocr_text),
            "tax": extract_tax(ocr_text),
            "discount": 0,
            "total": extract_total(ocr_text)
        },
        "additional_info": {
            "notes": "",
            "terms": ""
        }
    }

def is_valid_invoice(data: dict) -> bool:
    if not data:
        return False
    
    invoice_details = data.get("invoice_details", {})
    vendor_name = data.get("vendor_details", {}).get("name", "")
    customer_name = data.get("customer_details", {}).get("name", "")
    line_items = data.get("line_items", [])
    summary = data.get("summary", {})
    total = summary.get("total", 0)
    
    has_number = bool(invoice_details.get("invoice_number", ""))
    has_either_name = bool(vendor_name or customer_name)
    has_items_or_total = bool(line_items or (total and total > 0))
    
    return has_either_name and has_items_or_total

def extract_invoice_number(text: str) -> str:
    import re
    patterns = [
        r'\bInvoice\s*(?:No\.?|Number|#|ID)\s*[:\-]?\s*([A-Z0-9][A-Z0-9\-_/\.]{1,30})\b',
        r'\bInv(?:oice)?\s*#\s*([A-Z0-9][A-Z0-9\-_/\.]{1,30})\b',
        r'\bNO\.\s*([A-Z0-9][A-Z0-9\-_/\.]{1,30})\b',
        r'\b(INV[-\s#:]*[A-Z0-9][A-Z0-9\-_/\.]{1,15})\b',
    ]
    invalid_values = {"INVOICE", "NUMBER", "NO", "DATE"}
    for pattern in patterns:
        for match in re.finditer(pattern, text, re.IGNORECASE):
            candidate = match.group(1).strip().upper()
            if candidate not in invalid_values:
                return candidate
    return ""

def extract_date(text: str) -> str:
    import re
    patterns = [
        r'\b(\d{4}-\d{2}-\d{2})\b',
        r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b',
        r'(\d{1,2}\s+[A-Za-z]+\s+\d{4})',
        r'([A-Za-z]+\s+\d{1,2},?\s+\d{4})',
        r'Date[:\s]*([A-Za-z0-9\s,/-]+)',
    ]
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1).strip()
    return ""

def extract_currency(text: str) -> str:
    import re

    text_upper = text.upper()
    if '$' in text or 'USD' in text_upper or 'DOLLAR' in text_upper:
        return 'USD'
    elif (
        '₹' in text
        or 'INR' in text_upper
        or 'RUPEE' in text_upper
        or 'RUPEES' in text_upper
        or re.search(r'\bRS\.?\b', text_upper)
    ):
        return 'INR'
    elif '€' in text or 'EUR' in text_upper or 'EURO' in text_upper:
        return 'EUR'
    elif '£' in text or 'GBP' in text_upper or 'POUND' in text_upper:
        return 'GBP'
    elif '¥' in text or 'JPY' in text_upper or 'CNY' in text_upper or 'YEN' in text_upper:
        return 'JPY'
    return ''

def extract_vendor_name(text: str) -> str:
    import re
    patterns = [
        r'From:\s*([^\n]+)',
        r'Seller:\s*([^\n]+)',
        r'Company:\s*([^\n]+)',
    ]
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            name = match.group(1).strip()
            if len(name) >= 3:
                return name
    return ""

def extract_vendor_address(text: str) -> str:
    return ""

def extract_email(text: str) -> str:
    import re
    match = re.search(r'[\w\.-]+@[\w\.-]+\.\w+', text)
    return match.group(0) if match else ""

def extract_phone(text: str) -> str:
    import re
    patterns = [
        r'\b\d{10}\b',
        r'\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b',
    ]
    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            return match.group(0)
    return ""

def extract_customer_name(text: str) -> str:
    import re
    patterns = [
        r'To:\s*([^\n]+)',
        r'Bill\s*To:\s*([^\n]+)',
        r'Customer:\s*([^\n]+)',
    ]
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            name = match.group(1).strip()
            if len(name) >= 3:
                return name
    return ""

def extract_line_items(text: str) -> list:
    return []

def extract_subtotal(text: str) -> float:
    import re
    match = re.search(r'Sub\s*Total[:\s]*\$?([\d,]+\.?\d*)', text, re.IGNORECASE)
    if match:
        return float(match.group(1).replace(',', ''))
    return 0.0

def extract_tax(text: str) -> float:
    import re
    match = re.search(r'Tax[:\s]*\$?([\d,]+\.?\d*)', text, re.IGNORECASE)
    if match:
        return float(match.group(1).replace(',', ''))
    return 0.0

def extract_total(text: str) -> float:
    import re
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    patterns = [
        r'(?:Total\s*Due|Amount\s*Due|Grand\s*Total)[:\s]*\$?([\d,]+\.?\d*)',
        r'(?<!Sub)(?<!Grand\s)\bTotal\b[:\s]*\$?([\d,]+\.?\d*)',
    ]
    for line in reversed(lines):
        for pattern in patterns:
            match = re.search(pattern, line, re.IGNORECASE)
            if match:
                return float(match.group(1).replace(',', ''))
    return 0.0

def convert_pdf_to_images_and_extract(content: bytes) -> str:
    try:
        import tempfile
        import os
        import cv2
        import numpy as np
        
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
            tmp.write(content)
            tmp_path = tmp.name
        
        doc = fitz.open(tmp_path)
        all_text = []
        
        for page_num in range(len(doc)):
            page = doc[page_num]
            
            mat = fitz.Matrix(3, 3)
            pix = page.get_pixmap(matrix=mat)
            
            img_data = np.frombuffer(pix.samples, dtype=np.uint8)
            
            if pix.n == 1:
                img = img_data.reshape(pix.height, pix.width)
            else:
                img = img_data.reshape(pix.height, pix.width, pix.n)
                if pix.n == 4:
                    img = cv2.cvtColor(img, cv2.COLOR_RGBA2RGB)
                elif pix.n == 3:
                    img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
            
            page_text = ocr_image_simple(img)
            if page_text.strip():
                all_text.append(f"PAGE {page_num + 1}:\n{page_text}")
        
        doc.close()
        os.unlink(tmp_path)
        
        return "\n\n".join(all_text) if all_text else ""
        
    except Exception as e:
        print(f"PDF to image conversion error: {e}")
        return ""

def ocr_image_simple(img):
    import easyocr
    
    try:
        reader = easyocr.Reader(['en'], gpu=False)
        
        if len(img.shape) == 3:
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        else:
            gray = img
        
        _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        
        results = reader.readtext(binary, paragraph=True)
        
        lines = [result[1].strip() for result in results if result[2] > 0.4]
        
        return "\n".join(lines)
        
    except Exception as e:
        print(f"OCR error: {e}")
        return ""
