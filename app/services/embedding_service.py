from __future__ import annotations

import hashlib
import math
import re

from zhipuai import ZhipuAI

from app.config import settings

_VECTOR_SIZE = 2048
_TOKEN_PATTERN = re.compile(r"[\u4e00-\u9fffA-Za-z0-9_-]+")


class EmbeddingService:
    def __init__(self) -> None:
        self.client = ZhipuAI(api_key=settings.zhipu_api_key) if settings.zhipu_api_key else None
        self.last_error: str | None = None

    def embed_text(self, text: str) -> list[float]:
        if self.client is not None:
            try:
                response = self.client.embeddings.create(model="embedding-3", input=text)
                return response.data[0].embedding
            except Exception as exc:
                self.last_error = str(exc)
        return self._local_embed_text(text)

    def _local_embed_text(self, text: str) -> list[float]:
        vector = [0.0] * _VECTOR_SIZE
        normalized = text.lower().strip()
        tokens = _TOKEN_PATTERN.findall(normalized) or list(normalized)

        for index, token in enumerate(tokens):
            seed = hashlib.sha256(f"{index}:{token}".encode("utf-8")).digest()
            for offset in (0, 4):
                bucket = int.from_bytes(seed[offset : offset + 2], "big") % _VECTOR_SIZE
                sign = 1.0 if seed[offset + 2] % 2 == 0 else -1.0
                weight = 1.0 + (seed[offset + 3] / 255.0)
                vector[bucket] += sign * weight

        norm = math.sqrt(sum(value * value for value in vector))
        if norm == 0:
            return vector
        return [value / norm for value in vector]


_embedding_service: EmbeddingService | None = None


def get_embedding_service() -> EmbeddingService:
    global _embedding_service
    if _embedding_service is None:
        _embedding_service = EmbeddingService()
    return _embedding_service
