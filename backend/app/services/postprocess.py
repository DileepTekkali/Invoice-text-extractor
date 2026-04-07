import re

def clean_text(text):
    text = re.sub(r'\s+', ' ', text)
    
    text = fix_currency_symbols(text)
    
    text = re.sub(r'[^A-Za-z0-9.,:/\- ₹$€£¥]', '', text)
    
    return text.strip()

def fix_currency_symbols(text):
    patterns = [
        (r'\b7\.(\d{2})\b', r'₹\1'),
        (r'(?<!\w)7(?=\s*\d)', '₹'),
        (r'Rs\.?\s*(\d)', r'₹\1'),
        (r'\b1\.00\b', r'₹100'),
    ]
    
    for pattern, replacement in patterns:
        text = re.sub(pattern, replacement, text)
    
    return text

def fix_common_ocr_errors(text):
    replacements = {
        '8': '$',
        'S': '$',
        '|': 'I',
        '0': 'O',
        ' rn ': ' rn ',
        ' rn': ' rn',
        'cm': 'cm',
    }
    
    for old, new in replacements.items():
        text = text.replace(old, new)
    
    return text
