from fastapi import APIRouter, UploadFile, File, HTTPException
from app.services.pdf_service import extract_structured_data_from_pdf, extract_structured_data_from_image, format_extracted_data
from app.services.invoice_repository import create_invoice

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
        extraction_method = "groq"
        
        if filename_lower.endswith(".pdf"):
            structured_data = extract_structured_data_from_pdf(content)
            extraction_method = structured_data.get("metadata", {}).get("extraction_method", "groq")
        elif filename_lower.endswith((".jpg", ".jpeg", ".png", ".webp")):
            structured_data = extract_structured_data_from_image(content, filename)
            extraction_method = structured_data.get("metadata", {}).get("extraction_method", "groq")
        else:
            raise HTTPException(
                status_code=422, 
                detail="Invalid file format. Please upload a PDF or image (JPG, PNG, WEBP)."
            )
        
        full_text = structured_data.get("full_text", "")
        formatted_text = format_extracted_data(structured_data)
        
        invoices = structured_data.get("invoices", [])
        saved_invoice = None
        
        if invoices:
            invoice_data = invoices[0]
            invoice_data["filename"] = filename
            invoice_data["raw_text"] = full_text
            invoice_data["extraction_method"] = extraction_method
            invoice_data["line_items"] = invoice_data.get("line_items", [])
            invoice_data["tables"] = structured_data.get("tables", [])
            
            metadata = invoice_data.get("invoice_metadata", {})
            invoice_data["invoice_number"] = metadata.get("invoice_number", "")
            invoice_data["date"] = metadata.get("invoice_date", "")
            invoice_data["due_date"] = metadata.get("due_date")
            invoice_data["status"] = metadata.get("status")
            invoice_data["currency"] = metadata.get("currency", "INR")
            
            seller = invoice_data.get("seller_business", {})
            invoice_data["seller"] = seller
            
            customer = invoice_data.get("customer", {})
            invoice_data["customer"] = customer
            
            payment_info = invoice_data.get("payment_info", {})
            invoice_data["payment_info"] = payment_info
            
            financial = invoice_data.get("financial_summary", {})
            invoice_data["subtotal"] = financial.get("subtotal", 0)
            invoice_data["tax"] = financial.get("tax", 0)
            invoice_data["tax_breakdown"] = financial.get("tax_breakdown", {})
            invoice_data["discount"] = financial.get("discount", 0)
            invoice_data["total_amount"] = financial.get("total_amount", 0)
            
            additional = invoice_data.get("additional_details", {})
            invoice_data["additional_details"] = additional
            invoice_data["extra_fields"] = structured_data.get("extra_fields", {})
            
            saved_invoice = create_invoice(invoice_data)
        
        return {
            "text": formatted_text,
            "filename": filename,
            "status": "success",
            "structured_data": structured_data,
            "extraction_method": extraction_method,
            "invoice_id": saved_invoice.get("_id") if saved_invoice else None,
            "invoice": saved_invoice
        }
    
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error: {type(e).__name__}: {e}")
        raise HTTPException(status_code=500, detail=f"Processing error: {str(e)}")