from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.deps import get_store
from app.schemas.common import SuccessResponse
from app.schemas.products import CategoryTreeNode
from app.services.db_store import DatabaseStore

router = APIRouter()


@router.get("", response_model=SuccessResponse[list[CategoryTreeNode]])
def list_categories(
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[list[CategoryTreeNode]]:
    return SuccessResponse(data=[CategoryTreeNode(**item) for item in store.list_categories()])
