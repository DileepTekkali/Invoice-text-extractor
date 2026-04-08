# Invoice Text Extractor

A full-stack web application for extracting, processing, and managing invoice data from PDF documents and images using AI.

## Features

- **Upload & Extract**: Upload PDF or image files to extract invoice data
- **AI-Powered**: Uses Groq AI (Llama-4-Scout) for intelligent invoice parsing
- **MongoDB Storage**: Persistent storage for all invoice data
- **Responsive UI**: Flutter-based web interface works on all devices
- **Search & Filter**: Search invoices by number, name, GST, etc.
- **Duplicate Detection**: Prevents duplicate invoice uploads

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           INVOICE TEXT EXTRACTOR                              │
│                           ARCHITECTURE OVERVIEW                               │
└─────────────────────────────────────────────────────────────────────────────┘

                                    ┌─────────────┐
                                    │   USERS     │
                                    │  (Browser)  │
                                    └──────┬──────┘
                                           │
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                               FRONTEND (Flutter Web)                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  Dashboard  │  │   Upload    │  │    List     │  │   Details   │        │
│  │    Page     │  │   Dialog    │  │    View     │  │    Modal    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         API Service Layer                             │    │
│  │  • uploadFile()  • getInvoices()  • deleteInvoice()  • getStats()  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                           │
                                    HTTPS Requests
                                           │
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              BACKEND (FastAPI)                               │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                           API Routes                                  │    │
│  │  POST /upload  │  GET /invoices  │  GET/POST/PUT/DELETE /invoices/* │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                       Business Logic Layer                            │    │
│  │  • Invoice Validation    • Duplicate Check    • Data Transformation  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         Service Layer                                 │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐       │    │
│  │  │  PDF Service    │  │  Invoice Repo    │  │   Database      │       │    │
│  │  │  (Groq AI OCR)  │  │  (CRUD Ops)     │  │   (MongoDB)     │       │    │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘       │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                           │
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                               EXTERNAL SERVICES                               │
│  ┌──────────────────────┐                ┌──────────────────────┐         │
│  │      Groq API         │                │      MongoDB Atlas    │         │
│  │  (AI Text Extraction)│                │    (Cloud Database)   │         │
│  └──────────────────────┘                └──────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Tech Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Frontend** | Flutter Web | User interface |
| **Backend** | FastAPI (Python) | API server |
| **Database** | MongoDB | Data storage |
| **AI/OCR** | Groq API (Llama-4) | Invoice text extraction |
| **Hosting** | Firebase | Frontend deployment |
| **Backend Hosting** | Render | Backend deployment |

## Project Structure

```
Invoice-text-extractor/
│
├── backend/                          # FastAPI Backend
│   ├── app/
│   │   ├── main.py                  # FastAPI app entry point
│   │   ├── routes/
│   │   │   ├── upload.py           # File upload endpoint
│   │   │   └── invoices.py         # Invoice CRUD endpoints
│   │   └── services/
│   │       ├── database.py          # MongoDB connection
│   │       ├── invoice_repository.py # Database operations
│   │       └── pdf_service.py      # PDF/Image processing & AI
│   ├── .env                        # Environment variables
│   ├── requirements.txt             # Python dependencies
│   ├── start.sh                    # Production startup script
│   └── README.md                    # Backend documentation
│
├── invoice_web_app/                  # Flutter Frontend
│   ├── lib/
│   │   ├── main.dart               # App entry point
│   │   ├── models/
│   │   │   └── invoice_data.dart   # Data models
│   │   ├── screens/
│   │   │   └── main_dashboard.dart # Main dashboard UI
│   │   └── services/
│   │       ├── api_service.dart    # API calls
│   │       ├── storage_service.dart # Local storage
│   │       └── invoice_parser.dart # Data parsing
│   ├── web/
│   │   └── index.html              # Web entry point
│   ├── pubspec.yaml                # Flutter dependencies
│   └── README.md                   # Frontend documentation
│
└── README.md                       # This file
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            UPLOAD FLOW                                    │
└─────────────────────────────────────────────────────────────────────────┘

User selects file
       │
       ▼
Flutter File Picker
       │
       ▼
API Service (POST /upload)
       │
       ▼
FastAPI Route Handler
       │
       ├──► Validate File Type (PDF/Image)
       │
       ├──► Extract Text (PyMuPDF for PDF, Base64 for Image)
       │
       ├──► AI Processing (Groq API - Llama-4-Scout)
       │         │
       │         ▼
       │    Structured JSON Output
       │
       ├──► Validate Invoice Data
       │         │
       │         ▼
       │    Check for Required Fields
       │
       ├──► Check Duplicate
       │         │
       │         ▼
       │    Compare Invoice Number + Seller Name
       │
       └──► Save to MongoDB
                 │
                 ▼
           Return Response
                 │
                 ▼
           Show Success/Error Modal
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/upload` | Upload PDF/Image and extract invoice data |
| `GET` | `/invoices` | List all invoices (with pagination & search) |
| `GET` | `/invoices/{id}` | Get single invoice by ID |
| `POST` | `/invoices` | Create invoice manually |
| `PUT` | `/invoices/{id}` | Update invoice |
| `DELETE` | `/invoices/{id}` | Delete invoice |
| `GET` | `/stats` | Get invoice statistics |
| `GET` | `/health` | Health check endpoint |

## Invoice Data Schema

```json
{
  "_id": "ObjectId",
  "invoice_number": "INV-2026-001",
  "date": "2026-01-15",
  "due_date": "2026-02-15",
  "status": "pending",
  "currency": "INR",
  
  "seller": {
    "business_name": "Company Name",
    "business_address": "Full Address",
    "mobile_number": "+91-XXXXX",
    "gst_number": "XXXXXXXXXXXXX",
    "email": "company@email.com"
  },
  
  "customer": {
    "customer_name": "Customer Name",
    "customer_address": "Customer Address",
    "phone_number": "+91-XXXXX",
    "email": "customer@email.com"
  },
  
  "payment_info": {
    "payment_method": "UPI",
    "bank_name": "Bank Name",
    "upi_id": "up id@bank"
  },
  
  "line_items": [
    {
      "description": "Item description",
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
    "sgst": 18.00
  },
  "discount": 0,
  "total_amount": 236.00,
  
  "additional_details": {
    "notes": "Thank you for your business"
  },
  
  "filename": "invoice.pdf",
  "created_at": "2026-01-15T10:30:00",
  "updated_at": "2026-01-15T10:30:00"
}
```

## Setup & Installation

### Prerequisites

- Python 3.10+
- Flutter SDK 3.0+
- MongoDB Atlas account
- Groq API key

### Backend Setup

```bash
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your MongoDB and Groq credentials

# Run locally
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Frontend Setup

```bash
cd invoice_web_app

# Install dependencies
flutter pub get

# Update API URL in lib/services/api_service.dart
# static const String baseUrl = "http://localhost:8000";

# Run locally
flutter run -d chrome
```

## Deployment

### Backend (Render)

1. Create new Web Service on [Render](https://render.com)
2. Connect GitHub repository
3. Set build command: `pip install -r requirements.txt`
4. Set start command: `./start.sh`
5. Add environment variables:
   - `GROQ_API_KEY`
   - `MongoDbURL`

### Frontend (Firebase)

```bash
cd invoice_web_app

# Build
flutter build web

# Deploy
firebase deploy --only hosting
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GROQ_API_KEY` | Groq API key for AI processing | Yes |
| `MongoDbURL` | MongoDB connection string | Yes |
| `DATABASE_NAME` | Database name (default: invoicetextextractor) | No |

## Features Detail

### 1. File Upload
- Accepts PDF and image files (JPG, JPEG, PNG, WEBP)
- Maximum file size: Limited by server configuration
- Shows upload progress

### 2. AI Text Extraction
- Uses Groq API with Llama-4-Scout model
- Extracts structured data from invoice text
- Handles various invoice formats

### 3. Validation
- Checks for required invoice fields
- Validates file format
- Shows appropriate error messages

### 4. Duplicate Detection
- Checks by invoice number + seller name
- Prevents duplicate uploads
- Shows existing invoice info

### 5. Invoice Management
- View all invoices in list
- Search by number, name, GST
- View detailed invoice info
- Delete unwanted invoices

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| `422 Unprocessable Entity` | Invalid file format | Upload PDF or image only |
| `400 Bad Request` | Empty file | Upload valid file |
| `500 Internal Server Error` | Server issue | Check server logs |
| Network Error | Server down | Ensure backend is running |

## Security

- CORS enabled for all origins (configure for production)
- Environment variables for sensitive data
- No hardcoded credentials in code

## License

MIT License
