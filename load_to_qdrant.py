from qdrant_client import QdrantClient
from qdrant_client.models import VectorParams
import requests
import sys

from dotenv import load_dotenv
import os

# Load variables from .env file into environment
load_dotenv()  # loads from .env in current directory by default

# Now read the API key from the environment
QDRANT_API_KEY = os.getenv("QDRANT_API_KEY")

if QDRANT_API_KEY is None:
    raise RuntimeError("QDRANT_API_KEY environment variable is not set")

# 🔑 Replace this with your actual Qdrant API key
#QDRANT_API_KEY = "79678be37f7c2895adea6f750518366587e6ec00a95d41aa"  # <-- put your key here

# 🧠 Texts to embed
docs = ["The quick brown fox", "A lazy dog"]

# 🚀 Get embeddings from your local MiniLM API
try:
    resp = requests.post("http://localhost:8000/embed", json={"texts": docs})
    resp.raise_for_status()
    vectors = resp.json()["vectors"]
except Exception as e:
    print("❌ Failed to get embeddings:", e)
    sys.exit(1)

# 🗃️ Connect to Qdrant
client = QdrantClient(
    host="localhost",
    port=6333,
    api_key=QDRANT_API_KEY,
    https=False,        # 👈 add this line to disable TLS
)

# 🏗️ Create collection if it doesn't exist
collection_name = "docs"
if not client.collection_exists(collection_name):
    client.create_collection(
        collection_name=collection_name,
        vectors_config=VectorParams(size=384, distance="Cosine"),
    )
    print(f"✅ Created new collection: {collection_name}")
else:
    print(f"ℹ️ Collection '{collection_name}' already exists")

# 📥 Insert data
points = [
    {"id": i, "vector": vectors[i], "payload": {"text": docs[i]}}
    for i in range(len(docs))
]
client.upsert(collection_name=collection_name, points=points)

print(f"✅ Inserted {len(points)} points into Qdrant collection '{collection_name}'")

# 🔍 Search test
query = "fast fox"
qvec = requests.post("http://localhost:8000/embed", json={"texts": [query]}).json()["vectors"][0]
results = client.search(collection_name="docs", query_vector=qvec, limit=2)

print("\n🔍 Search results for:", query)
for r in results:
    print(f"• Score={r.score:.3f} | Text={r.payload['text']}")

