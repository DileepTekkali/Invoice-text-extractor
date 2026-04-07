import easyocr
import numpy as np
import cv2
import re
from app.services.postprocess import clean_text

reader = easyocr.Reader(['en'], gpu=False)

def process_file(file_bytes, filename):
    filename_lower = filename.lower()
    
    if filename_lower.endswith(".pdf"):
        text = extract_text_from_pdf(file_bytes)
        
        if text and len(text.strip()) >= 50:
            cleaned = clean_text_with_structure(text)
            if is_invoice(cleaned):
                return cleaned
            return f"NON_INVOICE:{cleaned}"
        
        ocr_text = ocr_pdf_pages(file_bytes)
        if is_invoice(ocr_text):
            return ocr_text
        return f"NON_INVOICE:{ocr_text}"
    
    ocr_text = ocr_image(file_bytes)
    if is_invoice(ocr_text):
        return ocr_text
    return f"NON_INVOICE:{ocr_text}"

def is_invoice(text):
    if not text or len(text.strip()) < 20:
        return False

    text_lower = text.lower()
    primary_keywords = [
        'invoice',
        'tax invoice',
        'sales invoice',
        'invoice number',
        'invoice no',
        'invoice #',
        'bill to',
        'amount due',
        'due date',
    ]
    secondary_keywords = [
        'subtotal',
        'total',
        'tax',
        'payment',
        'gstin',
        'customer',
        'vendor',
        'seller',
        'sold by',
        'ship to',
    ]

    primary_matches = sum(1 for kw in primary_keywords if kw in text_lower)
    secondary_matches = sum(1 for kw in secondary_keywords if kw in text_lower)
    has_amount_pattern = bool(
        re.search(
            r'(total|amount due|subtotal)\s*[:\-]?\s*[₹$€£¥]?\s*[\d,]+(?:\.\d{1,2})?',
            text_lower,
        )
    )

    return primary_matches >= 2 or (
        primary_matches >= 1 and (secondary_matches >= 1 or has_amount_pattern)
    )

def clean_text_with_structure(text):
    lines = text.split('\n')
    cleaned_lines = []
    
    for line in lines:
        line = line.strip()
        if line:
            line = re.sub(r'\s+', ' ', line)
            cleaned_lines.append(line)
    
    return '\n'.join(cleaned_lines)

def extract_text_from_pdf(file_bytes):
    import fitz
    import tempfile
    import os
    
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
            tmp.write(file_bytes)
            tmp_path = tmp.name
        
        doc = fitz.open(tmp_path)
        text_parts = []
        
        for page_num in range(len(doc)):
            page = doc[page_num]
            page_text = page.get_text("text")
            
            tables = extract_tables_from_page(page)
            if tables:
                page_text = merge_text_with_tables(page_text, tables)
            
            text_parts.append(page_text)
        
        doc.close()
        
        full_text = '\n'.join(text_parts)
        return full_text.strip()
        
    except Exception as e:
        return ""
    finally:
        if tmp_path:
            try:
                os.unlink(tmp_path)
            except:
                pass

def extract_tables_from_page(page):
    import fitz
    tables = []
    
    try:
        tabs = page.find_tables()
        if tabs:
            for tab in tabs:
                table_data = []
                for row in tab.extract():
                    if row and any(cell.strip() for cell in row):
                        table_data.append(row)
                if table_data:
                    tables.append(table_data)
    except:
        pass
    
    return tables

def merge_text_with_tables(text, tables):
    result = [text]
    
    for table in tables:
        result.append("\n---TABLE START---")
        for row in table:
            row_text = " | ".join([str(cell).strip() for cell in row if cell])
            if row_text:
                result.append(row_text)
        result.append("---TABLE END---\n")
    
    return '\n'.join(result)

def ocr_pdf_pages(file_bytes):
    import fitz
    import tempfile
    import os
    
    tmp_pdf = None
    all_text = []
    
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
            tmp.write(file_bytes)
            tmp_pdf = tmp.name
        
        doc = fitz.open(tmp_pdf)
        
        for page_num in range(len(doc)):
            page = doc[page_num]
            
            mat = fitz.Matrix(3, 3)
            pix = page.get_pixmap(matrix=mat)
            
            img_data = np.frombuffer(pix.samples, dtype=np.uint8)
            
            if pix.n == 1:
                img = img_data.reshape(pix.height, pix.width)
            else:
                img = img_data.reshape(pix.height, pix.width, pix.n)
                if pix.n == 4:
                    img = cv2.cvtColor(img, cv2.COLOR_RGBA2RGB)
            
            page_text = ocr_with_layout(img)
            if page_text.strip():
                all_text.append(f"PAGE {page_num + 1}:\n{page_text}")
            
            tables = extract_tables_from_page(page)
            for table in tables:
                table_lines = []
                for row in table:
                    row_text = " | ".join([str(cell).strip() for cell in row if cell])
                    if row_text:
                        table_lines.append(row_text)
                if table_lines:
                    all_text.append("---TABLE START---")
                    all_text.extend(table_lines)
                    all_text.append("---TABLE END---")
        
        doc.close()
        
        if all_text:
            return '\n'.join(all_text)
        return "No text found in PDF"
        
    except Exception as e:
        return f"Error processing PDF: {str(e)}"
    finally:
        if tmp_pdf:
            try:
                os.unlink(tmp_pdf)
            except:
                pass

def ocr_with_layout(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img
    
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    gray = clahe.apply(gray)
    
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    
    results = reader.readtext(binary, paragraph=False)
    
    sorted_results = sorted(results, key=lambda x: (round(x[0][0][1] / 20) * 20, x[0][0][0]))
    
    lines = []
    current_line = []
    current_y = None
    
    for detection in sorted_results:
        if detection[2] < 0.4:
            continue
            
        text = detection[1].strip()
        bbox = detection[0]
        
        y_pos = (bbox[0][1] + bbox[2][1]) / 2
        
        if current_y is None:
            current_y = y_pos
        elif abs(y_pos - current_y) > 20:
            if current_line:
                lines.append(' '.join(current_line))
            current_line = [text]
            current_y = y_pos
        else:
            current_line.append(text)
    
    if current_line:
        lines.append(' '.join(current_line))
    
    return '\n'.join(lines)

def ocr_image(file_bytes):
    nparr = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    if img is None:
        raise ValueError("Could not decode image")
    
    height, width = img.shape[:2]
    if width > 2500:
        scale = 2500 / width
        img = cv2.resize(img, None, fx=scale, fy=scale)
    
    return ocr_with_layout(img)
