from fastapi import APIRouter, UploadFile, File, HTTPException
from app.services.ocr_service import process_file

router = APIRouter()

@router.post("/upload")
async def upload_invoice(file: UploadFile = File(...)):
    try:
        content = await file.read()
        
        if not content or len(content) == 0:
            raise HTTPException(status_code=400, detail="Empty file received")
        
        filename = file.filename or "unknown"
        print(f"Processing file: {filename}, size: {len(content)} bytes")
        
        result = process_file(content, filename)
        
        if result.startswith("NON_INVOICE:"):
            actual_text = result[12:]
            raise HTTPException(
                status_code=422, 
                detail=f"The uploaded file does not appear to be an invoice. Please upload a valid invoice document."
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
