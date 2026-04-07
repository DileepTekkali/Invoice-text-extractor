import fitz
import tempfile
import os
import json

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

def extract_structured_data_from_pdf(file_bytes):
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
            tmp.write(file_bytes)
            tmp_path = tmp.name

        doc = fitz.open(tmp_path)
        all_text_parts = []
        tables_data = []
        metadata = {}
        
        for page_num in range(len(doc)):
            page = doc[page_num]
            page_text = page.get_text()
            all_text_parts.append(f"\n--- PAGE {page_num + 1} ---\n{page_text}")
            
            table_count = 0
            tables = page.find_tables()
            for table in tables:
                table_count += 1
                try:
                    extracted_table = table.extract()
                    if extracted_table and len(extracted_table) > 0:
                        table_info = {
                            "page": page_num + 1,
                            "table_index": table_count,
                            "headers": extracted_table[0] if extracted_table else [],
                            "rows": extracted_table[1:] if len(extracted_table) > 1 else [],
                            "raw_table": extracted_table
                        }
                        tables_data.append(table_info)
                except:
                    pass
            
            plain_text = page.get_text("text")
            metadata[f"page_{page_num + 1}"] = {
                "text": plain_text,
                "has_tables": table_count > 0,
                "table_count": table_count
            }
            
        doc.close()
        
        all_text = "".join(all_text_parts)
        
        result = {
            "full_text": all_text,
            "tables": tables_data,
            "metadata": metadata,
            "table_count": len(tables_data),
            "page_count": len(doc)
        }
        
        return result
    except Exception as e:
        return {
            "full_text": "",
            "tables": [],
            "metadata": {},
            "table_count": 0,
            "page_count": 0,
            "error": str(e)
        }
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)

def format_extracted_data(structured_data):
    formatted_text = structured_data.get("full_text", "")
    
    for table in structured_data.get("tables", []):
        page_num = table.get("page", 0)
        table_idx = table.get("table_index", 0)
        headers = table.get("headers", [])
        rows = table.get("rows", [])
        
        formatted_text += f"\n---TABLE START---\n"
        formatted_text += f"Table {table_idx} (Page {page_num})\n"
        
        if headers:
            formatted_text += " | ".join(str(h) if h else "" for h in headers) + "\n"
        
        for row in rows:
            formatted_text += " | ".join(str(cell) if cell else "" for cell in row) + "\n"
        
        formatted_text += "---TABLE END---\n"
    
    return formatted_text