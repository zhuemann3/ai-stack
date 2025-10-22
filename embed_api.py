# embed_api.py
from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
import uvicorn

# Load model once at startup (downloads the first time you run it)
model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

app = FastAPI(title="Local Embedding API", version="1.0")

class Texts(BaseModel):
    texts: list[str]

@app.post("/embed")
def embed_texts(data: Texts):
    """Return MiniLM-L6-v2 embeddings for an array of texts."""
    vectors = model.encode(data.texts, convert_to_numpy=True).tolist()
    return {"vectors": vectors}

if __name__ == "__main__":
    # Start the API server on http://localhost:8000
    uvicorn.run(app, host="0.0.0.0", port=8000)

