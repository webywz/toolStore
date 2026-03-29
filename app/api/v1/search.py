from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.core.deps import get_current_user, get_optional_user, get_store
from app.models.entities import User
from app.schemas.common import SuccessResponse
from app.schemas.search import SearchData, SearchHistoryItem, SearchRequest, SuggestionData
from app.services.db_store import DatabaseStore

router = APIRouter()


@router.post("/intelligent-search", response_model=SuccessResponse[SearchData])
def intelligent_search(
    payload: SearchRequest,
    store: Annotated[DatabaseStore, Depends(get_store)],
    user: Annotated[User | None, Depends(get_optional_user)],
) -> SuccessResponse[SearchData]:
    data = store.intelligent_search(
        query=payload.query,
        search_type=payload.search_type,
        category_id=payload.category_id,
        min_price=payload.min_price,
        max_price=payload.max_price,
        sort_by=payload.sort_by,
        page=payload.page,
        limit=payload.limit,
        user_id=user.id if user else None,
    )
    return SuccessResponse(data=SearchData(**data))


@router.get("/suggestions", response_model=SuccessResponse[SuggestionData])
def suggestions(
    store: Annotated[DatabaseStore, Depends(get_store)],
    q: str = Query(..., min_length=1),
) -> SuccessResponse[SuggestionData]:
    return SuccessResponse(data=SuggestionData(suggestions=store.search_suggestions(q)))


@router.get("/histories", response_model=SuccessResponse[list[SearchHistoryItem]])
def histories(
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[list[SearchHistoryItem]]:
    items = [SearchHistoryItem(**item) for item in store.get_search_histories(user.id)]
    return SuccessResponse(data=items)
