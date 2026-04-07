import fitz
import tempfile
import os

def extract_text_from_pdf(file_bytes):
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
            tmp.write(file_bytes)
            tmp_path = tmp.name

        doc = fitz.open(tmp_path)
        text = ""
        for page in doc:
            text += page.get_text()
        doc.close()
        return text.strip()
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)