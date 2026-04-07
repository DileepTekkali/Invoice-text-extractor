import cv2
import numpy as np

def preprocess_image(file_bytes):
    nparr = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    if img is None:
        raise ValueError("Could not decode image")
    
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Resize if too large
    height, width = gray.shape[:2]
    if width > 2000:
        scale = 2000 / width
        gray = cv2.resize(gray, None, fx=scale, fy=scale)
    
    return gray
