from fastapi import Request, HTTPException
from app.core.cache import get_cache

async def rate_limit_middleware(request: Request, call_next):
    cache = get_cache()
    if cache.available:
        client_ip = request.client.host
        key = f"rate_limit:{client_ip}"
        count = cache.get(key) or 0
        if count > 100:
            raise HTTPException(status_code=429, detail="请求过于频繁")
        cache.set(key, count + 1, 60)
    return await call_next(request)
