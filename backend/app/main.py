from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes.upload import router as upload_router
from app.routes.invoices import router as invoices_router

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(upload_router)
app.include_router(invoices_router)

@app.get("/")
def read_root():
    return {"message": "Invoice OCR API is running"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}
