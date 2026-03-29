from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.core.deps import get_current_user, get_store
from app.models.entities import User
from app.schemas.common import MessagePayload, SuccessResponse
from app.schemas.favorites import FavoriteListData, FavoriteProductItem
from app.services.db_store import DatabaseStore

router = APIRouter()


@router.post("/{product_id}", response_model=SuccessResponse[MessagePayload])
def add_favorite(
    product_id: int,
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[MessagePayload]:
    store.add_favorite(user.id, product_id)
    return SuccessResponse(data=MessagePayload(message="收藏成功"))


@router.delete("/{product_id}", response_model=SuccessResponse[MessagePayload])
def remove_favorite(
    product_id: int,
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[MessagePayload]:
    store.remove_favorite(user.id, product_id)
    return SuccessResponse(data=MessagePayload(message="已取消收藏"))


@router.get("", response_model=SuccessResponse[FavoriteListData])
def list_favorites(
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
) -> SuccessResponse[FavoriteListData]:
    data = store.list_favorites(user.id, page=page, limit=limit)
    products = [FavoriteProductItem(**item) for item in data["products"]]
    return SuccessResponse(data=FavoriteListData(total=data["total"], products=products))
