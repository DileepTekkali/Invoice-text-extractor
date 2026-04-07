from fastapi import APIRouter, UploadFile, File, HTTPException
from app.services.ocr_service import process_file
from app.services.pdf_service import extract_structured_data_from_pdf, format_extracted_data

router = APIRouter()

@router.post("/upload")
async def upload_invoice(file: UploadFile = File(...)):
    try:
        content = await file.read()
        
        if not content or len(content) == 0:
            raise HTTPException(status_code=400, detail="Empty file received")
        
        filename = file.filename or "unknown"
        print(f"Processing file: {filename}, size: {len(content)} bytes")
        
        filename_lower = filename.lower()
        
        if filename_lower.endswith(".pdf"):
            structured_data = extract_structured_data_from_pdf(content)
            
            if structured_data.get("table_count", 0) > 0:
                formatted_text = format_extracted_data(structured_data)
                
                if is_invoice_check(formatted_text):
                    return {
                        "text": formatted_text,
                        "filename": filename,
                        "status": "success",
                        "structured_data": structured_data,
                        "extraction_method": "pymupdf"
                    }
            
            result = process_file(content, filename)
        else:
            result = process_file(content, filename)
        
        if result.startswith("NON_INVOICE:"):
            raise HTTPException(
                status_code=422, 
                detail="The uploaded file does not appear to be an invoice. Please upload a valid invoice document."
            )
        
        print(f"OCR Result length: {len(result)} chars")
        
        return {"text": result, "filename": filename, "status": "success"}
    
    except HTTPException:
        raise
    except ValueError as e:
        print(f"ValueError: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"Error: {type(e).__name__}: {e}")
        raise HTTPException(status_code=500, detail=f"Processing error: {type(e).__name__}: {str(e)}")

def is_invoice_check(text):
    invoice_keywords = [
        'invoice', 'bill', 'receipt', 'tax invoice', 'sales invoice',
        'purchase', 'order', 'amount due', 'total', 'subtotal',
        'bill to', 'ship to', 'sold by', 'invoice number', 'inv#',
        'invoice date', 'due date', 'gstin', 'tax', 'payment'
    ]
    
    text_lower = text.lower()
    matches = sum(1 for kw in invoice_keywords if kw in text_lower)
    return matches >= 2
