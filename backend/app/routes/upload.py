from fastapi import APIRouter, UploadFile, File, HTTPException
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
            
            full_text = structured_data.get("full_text", "")
            formatted_text = format_extracted_data(structured_data)
            
            return {
                "text": formatted_text,
                "filename": filename,
                "status": "success",
                "structured_data": structured_data,
                "extraction_method": structured_data.get("metadata", {}).get("extraction_method", "groq")
            }
        
        raise HTTPException(
            status_code=422, 
            detail="Invalid file format. Please upload a PDF file."
        )
    
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error: {type(e).__name__}: {e}")
        raise HTTPException(status_code=500, detail=f"Processing error: {str(e)}")