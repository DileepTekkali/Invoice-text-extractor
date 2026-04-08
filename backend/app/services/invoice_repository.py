from bson import ObjectId
from datetime import datetime
from .database import get_invoices_collection
import json

def _to_float(val):
    if val is None:
        return 0.0
    if isinstance(val, (int, float)):
        return float(val)
    if isinstance(val, str):
        val = val.strip()
        try:
            return float(val.replace(',', ''))
        except:
            return 0.0
    return 0.0

def serialize_invoice(invoice):
    if invoice is None:
        return None
    invoice["_id"] = str(invoice["_id"])
    if "created_at" in invoice and isinstance(invoice["created_at"], datetime):
        invoice["created_at"] = invoice["created_at"].isoformat()
    if "updated_at" in invoice and isinstance(invoice["updated_at"], datetime):
        invoice["updated_at"] = invoice["updated_at"].isoformat()
    return invoice

def convert_to_serializable(obj, seen=None):
    if seen is None:
        seen = set()
    
    obj_id = id(obj)
    if obj_id in seen:
        return None
    seen.add(obj_id)
    
    try:
        if isinstance(obj, dict):
            return {str(k): convert_to_serializable(v, seen) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [convert_to_serializable(item, seen) for item in obj]
        elif isinstance(obj, (str, int, float, bool, type(None))):
            return obj
        else:
            return str(obj)
    finally:
        seen.discard(obj_id)

def create_invoice(invoice_data):
    collection = get_invoices_collection()
    
    def _safe_str(val):
        if val is None:
            return ""
        if isinstance(val, str):
            return val.strip()
        return str(val)
    
    def _safe_float(val):
        if val is None:
            return 0.0
        if isinstance(val, (int, float)):
            return float(val)
        if isinstance(val, str):
            val = val.strip()
            try:
                return float(val.replace(',', ''))
            except:
                return 0.0
        return 0.0
    
    def _safe_dict(val):
        if val is None:
            return {}
        if isinstance(val, dict):
            return convert_to_serializable(val)
        return {}
    
    def _safe_list(val):
        if val is None:
            return []
        if isinstance(val, list):
            return convert_to_serializable(val)
        return []
    
    document = {
        "invoice_number": _safe_str(invoice_data.get("invoice_number")),
        "date": _safe_str(invoice_data.get("date")),
        "due_date": _safe_str(invoice_data.get("due_date")) or None,
        "status": _safe_str(invoice_data.get("status")) or None,
        "currency": _safe_str(invoice_data.get("currency")) or "INR",
        
        "seller": _safe_dict(invoice_data.get("seller")),
        "customer": _safe_dict(invoice_data.get("customer")),
        "payment_info": _safe_dict(invoice_data.get("payment_info")),
        
        "line_items": _safe_list(invoice_data.get("line_items")),
        "tables": _safe_list(invoice_data.get("tables")),
        
        "subtotal": _safe_float(invoice_data.get("subtotal")),
        "tax": _safe_float(invoice_data.get("tax")),
        "tax_breakdown": _safe_dict(invoice_data.get("tax_breakdown")),
        "discount": _safe_float(invoice_data.get("discount")),
        "total_amount": _safe_float(invoice_data.get("total_amount")),
        
        "additional_details": _safe_dict(invoice_data.get("additional_details")),
        "extra_fields": _safe_dict(invoice_data.get("extra_fields")),
        
        "raw_text": _safe_str(invoice_data.get("raw_text"))[:50000],
        "filename": _safe_str(invoice_data.get("filename")),
        "extraction_method": _safe_str(invoice_data.get("extraction_method")),
        
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }
    
    result = collection.insert_one(document)
    document["_id"] = str(result.inserted_id)
    document["created_at"] = document["created_at"].isoformat()
    document["updated_at"] = document["updated_at"].isoformat()
    
    return document

def get_all_invoices(page=1, limit=50, search=None):
    collection = get_invoices_collection()
    
    query = {}
    if search:
        query["$or"] = [
            {"invoice_number": {"$regex": search, "$options": "i"}},
            {"seller.business_name": {"$regex": search, "$options": "i"}},
            {"customer.customer_name": {"$regex": search, "$options": "i"}},
            {"seller.gst_number": {"$regex": search, "$options": "i"}},
        ]
    
    skip = (page - 1) * limit
    
    total = collection.count_documents(query)
    invoices = list(collection.find(query).sort("created_at", -1).skip(skip).limit(limit))
    
    invoices = [serialize_invoice(inv) for inv in invoices]
    
    return {
        "invoices": invoices,
        "total": total,
        "page": page,
        "limit": limit,
        "total_pages": (total + limit - 1) // limit
    }

def get_invoice_by_id(invoice_id):
    collection = get_invoices_collection()
    
    try:
        invoice = collection.find_one({"_id": ObjectId(invoice_id)})
        return serialize_invoice(invoice)
    except:
        return None

def update_invoice(invoice_id, update_data):
    collection = get_invoices_collection()
    
    update_fields = {}
    
    allowed_fields = [
        "invoice_number", "date", "due_date", "status", "currency",
        "seller", "customer", "payment_info",
        "line_items", "tables",
        "subtotal", "tax", "tax_breakdown", "discount", "total_amount",
        "additional_details", "extra_fields"
    ]
    
    for field in allowed_fields:
        if field in update_data:
            update_fields[field] = update_data[field]
    
    update_fields["updated_at"] = datetime.utcnow()
    
    try:
        result = collection.update_one(
            {"_id": ObjectId(invoice_id)},
            {"$set": update_fields}
        )
        
        if result.modified_count > 0:
            return get_invoice_by_id(invoice_id)
        return None
    except:
        return None

def delete_invoice(invoice_id):
    collection = get_invoices_collection()
    
    try:
        result = collection.delete_one({"_id": ObjectId(invoice_id)})
        return result.deleted_count > 0
    except:
        return False

def get_invoice_stats():
    collection = get_invoices_collection()
    
    total_invoices = collection.count_documents({})
    
    pipeline = [
        {
            "$group": {
                "_id": None,
                "total_amount": {"$sum": "$total_amount"},
                "total_tax": {"$sum": "$tax"},
                "avg_amount": {"$avg": "$total_amount"}
            }
        }
    ]
    
    stats = list(collection.aggregate(pipeline))
    
    return {
        "total_invoices": total_invoices,
        "total_amount": stats[0]["total_amount"] if stats else 0,
        "total_tax": stats[0]["total_tax"] if stats else 0,
        "avg_amount": stats[0]["avg_amount"] if stats else 0
    }
