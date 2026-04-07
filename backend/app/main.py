import logging
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes.upload import router as upload_router

app = FastAPI()

DEFAULT_FRONTEND_ORIGINS = [
    "https://invoice-text-extractor.web.app",
    "https://invoice-text-extractor.firebaseapp.com",
]


def _get_allowed_origins() -> tuple[list[str], bool]:
    raw_origins = os.environ.get("FRONTEND_ORIGINS", "").strip()
    origins = [origin.strip() for origin in raw_origins.split(",") if origin.strip()]
    if not origins:
        origins = DEFAULT_FRONTEND_ORIGINS

    allow_credentials = bool(origins and origins != ["*"])
    return origins, allow_credentials


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


allowed_origins, allow_credentials = _get_allowed_origins()
logger.info("CORS allow_origins=%s allow_credentials=%s", allowed_origins, allow_credentials)

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(upload_router)

@app.get("/")
def read_root():
    return {"message": "Invoice OCR API is running"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}
