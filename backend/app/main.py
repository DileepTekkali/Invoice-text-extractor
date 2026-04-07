import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes.upload import router as upload_router

app = FastAPI()


def _get_allowed_origins() -> tuple[list[str], bool]:
    raw_origins = os.environ.get("FRONTEND_ORIGINS", "").strip()
    if not raw_origins:
        return ["*"], False

    origins = [origin.strip() for origin in raw_origins.split(",") if origin.strip()]
    if not origins:
        return ["*"], False

    return origins, True


allowed_origins, allow_credentials = _get_allowed_origins()

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
