from fastapi import FastAPI, File, UploadFile, HTTPException
import pytesseract
from PIL import Image
import pdfplumber
import io
import csv
import docx
import chardet

app = FastAPI(title="Local OCR API", description="Lightweight local file text extractor with multi-format support")

@app.post("/file")
async def extract_text(file: UploadFile = File(...)):
    try:
        filename = file.filename
        content = await file.read()
        if not content:
            raise HTTPException(status_code=400, detail="Empty file upload")

        filetype = "unknown"
        text = ""

        # --- Detect format ---
        name = filename.lower()
        if name.endswith(".pdf"):
            filetype = "pdf"
            with pdfplumber.open(io.BytesIO(content)) as pdf:
                for page in pdf.pages:
                    page_text = page.extract_text()
                    if page_text:
                        text += page_text + "\n"

        elif any(name.endswith(ext) for ext in [".png", ".jpg", ".jpeg", ".tiff", ".bmp", ".gif"]):
            filetype = "image"
            image = Image.open(io.BytesIO(content))
            text = pytesseract.image_to_string(image)

        elif name.endswith(".txt"):
            filetype = "txt"
            encoding = chardet.detect(content)["encoding"] or "utf-8"
            text = content.decode(encoding, errors="ignore")

        elif name.endswith(".csv"):
            filetype = "csv"
            encoding = chardet.detect(content)["encoding"] or "utf-8"
            decoded = content.decode(encoding, errors="ignore")
            reader = csv.reader(io.StringIO(decoded))
            lines = ["\t".join(row) for row in reader]
            text = "\n".join(lines)

        elif name.endswith(".docx"):
            filetype = "docx"
            doc = docx.Document(io.BytesIO(content))
            text = "\n".join([p.text for p in doc.paragraphs])

        else:
            filetype = "unsupported"
            text = "[Unsupported file type]"

        text = text.strip() if text else ""
        if not text:
            text = "[No readable text extracted]"

        return {
            "filename": filename,
            "type": filetype,
            "length": len(text),
            "text": text[:2000] + ("..." if len(text) > 2000 else "")
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))