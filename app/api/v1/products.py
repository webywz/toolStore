from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.core.deps import get_store
from app.schemas.common import SuccessResponse
from app.schemas.products import ProductDetailData, ProductListData
from app.services.db_store import DatabaseStore

router = APIRouter()


@router.get("", response_model=SuccessResponse[ProductListData])
def list_products(
    store: Annotated[DatabaseStore, Depends(get_store)],
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    category_id: int | None = Query(default=None),
    keyword: str | None = Query(default=None),
) -> SuccessResponse[ProductListData]:
    data = store.list_products(page=page, limit=limit, category_id=category_id, keyword=keyword)
    return SuccessResponse(data=ProductListData(**data))


@router.get("/{product_id}", response_model=SuccessResponse[ProductDetailData])
def product_detail(
    product_id: int,
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[ProductDetailData]:
    product = store.get_product(product_id)
    return SuccessResponse(
        data=ProductDetailData(
            id=product["id"],
            name=product["name"],
            category_id=product["category_id"],
            brand=product["brand"],
            model=product["model"],
            category=product["category"],
            price=product["price"],
            images=product["images"],
            description=product["description"],
            specs=product["specs"],
            compatibility=product["compatibility"],
            usage_scenarios=product["usage_scenarios"],
            safety_tips=product["safety_tips"],
            keywords=product["keywords"],
            created_at=product["created_at"],
        )
    )
