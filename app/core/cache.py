import json
from typing import Any
import redis
from app.config import settings

class CacheService:
    def __init__(self):
        try:
            self.client = redis.from_url(settings.redis_url, decode_responses=True)
            self.client.ping()
            self.available = True
        except:
            self.client = None
            self.available = False
    
    def get(self, key: str) -> Any:
        if not self.available:
            return None
        try:
            value = self.client.get(key)
            return json.loads(value) if value else None
        except:
            return None
    
    def set(self, key: str, value: Any, ttl: int = 300):
        if not self.available:
            return
        try:
            self.client.setex(key, ttl, json.dumps(value))
        except:
            pass

_cache = None

def get_cache() -> CacheService:
    global _cache
    if _cache is None:
        _cache = CacheService()
    return _cache
