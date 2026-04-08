# Invoice Text Extractor - Backend

A FastAPI-based backend service for extracting structured data from invoice documents (PDF and images) using Groq AI.

## Features

- Extract text from PDF files
- Extract text from images (JPG, JPEG, PNG, WEBP)
- AI-powered invoice data extraction using Groq
- MongoDB storage for invoice data
- RESTful API with FastAPI

## Tech Stack

- **Framework**: FastAPI
- **OCR/AI**: Groq API (Llama-4-Scout)
- **Database**: MongoDB
- **PDF Processing**: PyMuPDF
- **Server**: Uvicorn

## Project Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI app entry point
│   ├── routes/
│   │   ├── __init__.py
│   │   ├── upload.py        # File upload endpoint
│   │   └── invoices.py      # Invoice CRUD endpoints
│   └── services/
│       ├── __init__.py
│       ├── database.py          # MongoDB connection
│       ├── invoice_repository.py # Database operations
│       └── pdf_service.py       # PDF/Image processing & AI extraction
├── .env                     # Environment variables (create from .env.example)
├── .env.example            # Example environment variables
├── requirements.txt         # Python dependencies
├── run.sh                  # Development startup script
├── start.sh                # Production startup script
└── README.md
```

## Setup

### Prerequisites

- Python 3.10+
- MongoDB (local or Atlas)
- Groq API key

### Installation

1. Create virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your credentials
```

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GROQ_API_KEY` | Your Groq API key | Yes |
| `MongoDbURL` | MongoDB connection string | Yes |
| `DATABASE_NAME` | MongoDB database name (default: invoicetextextractor) | No |

### Running Locally

Development (with auto-reload):
```bash
./run.sh
# or
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Production:
```bash
./start.sh
# or
uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

## API Endpoints

### Upload Invoice
```
POST /upload
Content-Type: multipart/form-data

file: PDF or image file (jpg, jpeg, png, webp)

Response:
{
    "text": "Formatted extracted text",
    "filename": "invoice.pdf",
    "status": "success",
    "structured_data": {...},
    "extraction_method": "groq",
    "invoice_id": "...",
    "invoice": {...}
}
```

### List Invoices
```
GET /invoices?page=1&limit=50&search=query

Response:
{
    "invoices": [...],
    "total": 100,
    "page": 1,
    "limit": 50,
    "total_pages": 2
}
```

### Get Invoice by ID
```
GET /invoices/{invoice_id}

Response: Invoice object
```

### Update Invoice
```
PUT /invoices/{invoice_id}

Body: Invoice fields to update

Response: Updated invoice object
```

### Delete Invoice
```
DELETE /invoices/{invoice_id}

Response: {"message": "Invoice deleted successfully"}
```

### Get Statistics
```
GET /stats

Response:
{
    "total_invoices": 100,
    "total_amount": 50000.00,
    "total_tax": 5000.00,
    "avg_amount": 500.00
}
```

### Health Check
```
GET /health

Response: {"status": "healthy"}
```

## Invoice Data Schema

```json
{
    "_id": "ObjectId",
    "invoice_number": "INV-001",
    "date": "2026-01-15",
    "due_date": "2026-02-15",
    "status": "paid",
    "currency": "INR",
    "seller": {
        "business_name": "Company Name",
        "business_address": "Address",
        "mobile_number": "+91-xxxx",
        "gst_number": "XXXXXXXXXXXXX",
        "email": "email@company.com"
    },
    "customer": {
        "customer_name": "Customer Name",
        "customer_address": "Address",
        "phone_number": "+91-xxxx",
        "email": "customer@email.com"
    },
    "payment_info": {
        "payment_method": "UPI",
        "bank_name": "Bank Name",
        "account_number": "XXXX",
        "upi_id": "up id"
    },
    "line_items": [
        {
            "description": "Item 1",
            "quantity": 2,
            "rate": 100.00,
            "amount": 200.00,
            "hsn_sac": "1234"
        }
    ],
    "subtotal": 200.00,
    "tax": 36.00,
    "tax_breakdown": {
        "cgst": 18.00,
        "sgst": 18.00,
        "igst": 0
    },
    "discount": 0,
    "total_amount": 236.00,
    "additional_details": {
        "notes": "Thank you",
        "terms_and_conditions": "..."
    },
    "raw_text": "Original extracted text...",
    "filename": "invoice.pdf",
    "extraction_method": "groq",
    "created_at": "2026-01-15T10:30:00",
    "updated_at": "2026-01-15T10:30:00"
}
```

## Deployment

### Render.com

1. Create a new Web Service on Render
2. Connect your GitHub repository
3. Set build command: `pip install -r requirements.txt`
4. Set start command: `./start.sh`
5. Add environment variables:
   - `GROQ_API_KEY`
   - `MongoDbURL`
   - `DATABASE_NAME`

## License

MIT License
