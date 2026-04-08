# Invoice Text Extractor - Frontend

A Flutter Web application for uploading, processing, and managing invoice documents.

## Features

- Upload PDF and image files
- Extract invoice data using AI
- View invoice details in a structured format
- Search and filter invoices
- Delete invoices
- Responsive design

## Tech Stack

- **Framework**: Flutter Web
- **State Management**: Flutter built-in State Management
- **HTTP Client**: http package
- **File Picker**: file_picker package
- **Hosting**: Firebase Hosting

## Project Structure

```
invoice_web_app/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/
│   │   └── invoice_data.dart      # Invoice data models
│   ├── screens/
│   │   └── main_dashboard.dart    # Main dashboard screen
│   └── services/
│       ├── api_service.dart       # API calls
│       ├── storage_service.dart   # Local storage
│       └── invoice_parser.dart    # Invoice parsing logic
├── web/
│   ├── index.html
│   └── firebase.json              # Firebase configuration
├── pubspec.yaml                   # Flutter dependencies
├── .firebaserc                    # Firebase project config
├── firebase.json                  # Firebase hosting config
└── README.md
```

## Setup

### Prerequisites

- Flutter SDK 3.0+
- Chrome/Web browser for testing

### Installation

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Update API base URL in `lib/services/api_service.dart`:
```dart
static const String baseUrl = "https://your-backend-url.onrender.com";
```

### Running Locally

```bash
flutter run -d chrome
```

### Building

```bash
flutter build web
```

## Configuration

### API Service

Update the `baseUrl` in `lib/services/api_service.dart` to point to your backend:

```dart
class ApiService {
  static const String baseUrl = "https://your-backend-url.onrender.com";
  // ...
}
```

### File Picker

The app uses `file_picker` for selecting PDF and image files. Supported formats:
- PDF: `.pdf`
- Images: `.jpg`, `.jpeg`, `.png`, `.webp`

## Features

### Upload Invoice
- Click "Upload PDF" or "Upload Image" buttons
- Select a file from your device
- The file is sent to the backend for processing
- Invoice data is extracted and displayed

### View Invoice Details
- Click on any invoice in the list
- View structured invoice information including:
  - Invoice metadata (number, date, status)
  - Seller/Business information
  - Customer information
  - Payment details
  - Line items
  - Financial summary (subtotal, tax, total)
  - Additional details
  - Raw extracted text

### Search Invoices
- Use the search bar to filter invoices
- Search by invoice number, business name, customer name, or GST number

### Delete Invoice
- Click the delete icon on any invoice
- Confirm deletion in the dialog

## Invoice Data Display

The app displays invoice data in a structured format:

### Invoice Information
- Invoice Number
- Date
- Due Date
- Payment Terms
- Submitted Date

### Company Information (Seller)
- Business Name
- Address
- Phone
- Email
- GSTIN

### Customer Information (Bill To)
- Customer Name
- Address
- Phone
- Email
- PO Number

### Financial Summary
- Subtotal
- GST/Tax
- Total Amount

### Line Items
- Description
- Quantity
- Rate
- Amount
- HSN/SAC Code

## Deployment

### Firebase Hosting

1. Install Firebase CLI:
```bash
npm install -g firebase-tools
```

2. Login to Firebase:
```bash
firebase login
```

3. Initialize Firebase (if not already done):
```bash
firebase init hosting
```
Select:
- Public directory: `build/web`
- Single-page app: No
- Don't overwrite index.html

4. Build and deploy:
```bash
flutter build web
firebase deploy --only hosting
```

### Build Output

The built web app is located in `build/web/` directory. Upload this to any static hosting service.

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.6.0
  cupertino_icons: ^1.0.8
  file_picker: ^11.0.2
  intl: ^0.20.2
  shared_preferences: ^2.5.5
```

## API Integration

The frontend integrates with the backend API for:

1. **Upload File**: `POST /upload`
   - Sends PDF/image to backend
   - Receives extracted invoice data

2. **Get Invoices**: `GET /invoices`
   - Fetches list of invoices from database
   - Supports pagination and search

3. **Get Invoice**: `GET /invoices/{id}`
   - Fetches single invoice by ID

4. **Update Invoice**: `PUT /invoices/{id}`
   - Updates invoice data

5. **Delete Invoice**: `DELETE /invoices/{id}`
   - Removes invoice from database

6. **Get Stats**: `GET /stats`
   - Fetches invoice statistics

## License

MIT License
