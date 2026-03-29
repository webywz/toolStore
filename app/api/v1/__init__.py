from fastapi import APIRouter

from app.api.v1.ai import router as ai_router
from app.api.v1.auth import router as auth_router
from app.api.v1.categories import router as categories_router
from app.api.v1.favorites import router as favorites_router
from app.api.v1.internal import router as internal_router
from app.api.v1.products import router as products_router
from app.api.v1.search import router as search_router
from app.api.v1.users import router as users_router

api_router = APIRouter()
api_router.include_router(auth_router, prefix="/auth", tags=["auth"])
api_router.include_router(users_router, prefix="/users", tags=["users"])
api_router.include_router(products_router, prefix="/products", tags=["products"])
api_router.include_router(categories_router, prefix="/categories", tags=["categories"])
api_router.include_router(search_router, prefix="/search", tags=["search"])
api_router.include_router(ai_router, prefix="/ai", tags=["ai"])
api_router.include_router(favorites_router, prefix="/favorites", tags=["favorites"])
api_router.include_router(internal_router, prefix="/internal", tags=["internal"])
