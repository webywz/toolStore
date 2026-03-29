from __future__ import annotations

import math

from qdrant_client import QdrantClient
from qdrant_client.models import Distance, PointStruct, VectorParams

from app.config import settings


class VectorStore:
    def __init__(self) -> None:
        self.collection = "product_knowledge"
        self.client: QdrantClient | None = None
        self.available = False
        self.last_error: str | None = None
        self._fallback_vectors: dict[int, list[float]] = {}
        try:
            self.client = QdrantClient(url=settings.qdrant_url, check_compatibility=False)
            self._ensure_collection()
            self.available = True
        except Exception as exc:
            self.last_error = str(exc)

    def _ensure_collection(self) -> None:
        if self.client is None:
            return
        collections = self.client.get_collections().collections
        if not any(c.name == self.collection for c in collections):
            self.client.create_collection(
                collection_name=self.collection,
                vectors_config=VectorParams(size=2048, distance=Distance.COSINE),
            )

    def reset(self) -> bool:
        self._fallback_vectors.clear()
        if not self.available or self.client is None:
            return True
        try:
            collections = self.client.get_collections().collections
            if any(c.name == self.collection for c in collections):
                self.client.delete_collection(self.collection)
            self.client.create_collection(
                collection_name=self.collection,
                vectors_config=VectorParams(size=2048, distance=Distance.COSINE),
            )
            return True
        except Exception as exc:
            self.available = False
            self.last_error = str(exc)
            return True

    def upsert(self, knowledge_id: int, vector: list[float]) -> bool:
        self._fallback_vectors[knowledge_id] = vector
        if not self.available or self.client is None:
            return True
        try:
            self.client.upsert(
                collection_name=self.collection,
                points=[PointStruct(id=knowledge_id, vector=vector)],
            )
            return True
        except Exception as exc:
            self.available = False
            self.last_error = str(exc)
            return True

    def search(self, vector: list[float], limit: int = 5) -> list[int]:
        if self.available and self.client is not None:
            try:
                results = self.client.search(collection_name=self.collection, query_vector=vector, limit=limit)
                return [int(r.id) for r in results]
            except Exception as exc:
                self.available = False
                self.last_error = str(exc)
        return self._fallback_search(vector, limit)

    def _fallback_search(self, vector: list[float], limit: int) -> list[int]:
        if not self._fallback_vectors:
            return []
        vector_norm = math.sqrt(sum(value * value for value in vector))
        if vector_norm == 0:
            return []
        scored: list[tuple[float, int]] = []
        for knowledge_id, stored_vector in self._fallback_vectors.items():
            dot = sum(left * right for left, right in zip(vector, stored_vector))
            stored_norm = math.sqrt(sum(value * value for value in stored_vector))
            if stored_norm == 0:
                continue
            scored.append((dot / (vector_norm * stored_norm), knowledge_id))
        scored.sort(key=lambda item: (item[0], item[1]), reverse=True)
        return [knowledge_id for score, knowledge_id in scored[:limit] if score > 0]


_vector_store: VectorStore | None = None


def get_vector_store() -> VectorStore:
    global _vector_store
    if _vector_store is None:
        _vector_store = VectorStore()
    return _vector_store
