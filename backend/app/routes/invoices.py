from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import Optional, Dict, List, Any
from app.services.invoice_repository import (
    create_invoice,
    get_all_invoices,
    get_invoice_by_id,
    update_invoice,
    delete_invoice,
    get_invoice_stats
)

router = APIRouter()

class InvoiceCreate(BaseModel):
    invoice_number: Optional[str] = ""
    date: Optional[str] = ""
    due_date: Optional[str] = None
    status: Optional[str] = None
    currency: Optional[str] = "INR"
    seller: Optional[Dict[str, Any]] = {}
    customer: Optional[Dict[str, Any]] = {}
    payment_info: Optional[Dict[str, Any]] = {}
    line_items: Optional[List[Dict[str, Any]]] = []
    tables: Optional[List[Dict[str, Any]]] = []
    subtotal: Optional[float] = 0
    tax: Optional[float] = 0
    tax_breakdown: Optional[Dict[str, Any]] = {}
    discount: Optional[float] = 0
    total_amount: Optional[float] = 0
    additional_details: Optional[Dict[str, Any]] = {}
    extra_fields: Optional[Dict[str, Any]] = {}
    raw_text: Optional[str] = ""
    filename: Optional[str] = ""
    structured_data: Optional[Dict[str, Any]] = {}
    extraction_method: Optional[str] = ""

class InvoiceUpdate(BaseModel):
    invoice_number: Optional[str] = None
    date: Optional[str] = None
    due_date: Optional[str] = None
    status: Optional[str] = None
    currency: Optional[str] = None
    seller: Optional[Dict[str, Any]] = None
    customer: Optional[Dict[str, Any]] = None
    payment_info: Optional[Dict[str, Any]] = None
    line_items: Optional[List[Dict[str, Any]]] = None
    tables: Optional[List[Dict[str, Any]]] = None
    subtotal: Optional[float] = None
    tax: Optional[float] = None
    tax_breakdown: Optional[Dict[str, Any]] = None
    discount: Optional[float] = None
    total_amount: Optional[float] = None
    additional_details: Optional[Dict[str, Any]] = None
    extra_fields: Optional[Dict[str, Any]] = None

@router.get("/invoices")
async def list_invoices(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    search: Optional[str] = None
):
    return get_all_invoices(page=page, limit=limit, search=search)

@router.get("/invoices/{invoice_id}")
async def get_invoice(invoice_id: str):
    invoice = get_invoice_by_id(invoice_id)
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")
    return invoice

@router.post("/invoices")
async def add_invoice(invoice: InvoiceCreate):
    invoice_data = invoice.model_dump(exclude_none=True)
    return create_invoice(invoice_data)

@router.put("/invoices/{invoice_id}")
async def modify_invoice(invoice_id: str, invoice: InvoiceUpdate):
    update_data = invoice.model_dump(exclude_none=True)
    result = update_invoice(invoice_id, update_data)
    if not result:
        raise HTTPException(status_code=404, detail="Invoice not found or update failed")
    return result

@router.delete("/invoices/{invoice_id}")
async def remove_invoice(invoice_id: str):
    if delete_invoice(invoice_id):
        return {"message": "Invoice deleted successfully"}
    raise HTTPException(status_code=404, detail="Invoice not found")

@router.get("/stats")
async def get_stats():
    return get_invoice_stats()
