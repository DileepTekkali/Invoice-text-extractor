# Deployment

## Current State

- Frontend can be deployed as Flutter web on Firebase Hosting.
- Backend can be deployed as FastAPI on Render.
- Supabase tables are created, but the app is still storing invoice list data in browser `shared_preferences`.
- That means deployment works now for OCR/extraction, but invoice persistence is not yet using Supabase until the backend/frontend save flow is integrated.

## Frontend: Firebase Hosting

Run from `invoice_web_app`:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://your-render-backend.onrender.com
firebase login
firebase use your-firebase-project-id
firebase deploy --only hosting
```

Files already prepared:

- `invoice_web_app/firebase.json`
- `invoice_web_app/.firebaserc.example`

Notes:

- The Hosting public directory is `build/web`.
- SPA rewrite to `/index.html` is enabled.

## Backend: Render

Create a Render Web Service with:

- Root directory: `backend`
- Build command: `pip install -r requirements.txt`
- Start command: `bash start.sh`
- Health check path: `/health`

Files already prepared:

- `backend/start.sh`
- `backend/.python-version`
- `backend/.env.example`

Set these Render environment variables:

```text
GEMINI_API_KEY=...
GEMINI_MODEL=gemini-2.5-flash
FRONTEND_ORIGINS=https://your-project.web.app,https://your-project.firebaseapp.com
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=...
```

## Supabase

The database schema is ready, but code integration is still pending.

To fully use Supabase you still need:

1. Backend insert/update logic for `invoices`
2. Backend insert logic for `invoice_items`
3. Backend insert logic for `invoice_tax_lines`
4. Backend insert logic for `invoice_custom_fields`
5. Frontend list loading from backend/Supabase instead of local `shared_preferences`
