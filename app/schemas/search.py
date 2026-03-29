from datetime import datetime

from pydantic import BaseModel, Field


class SearchRequest(BaseModel):
    query: str
    search_type: str = "auto"
    category_id: int | None = None
    min_price: float | None = None
    max_price: float | None = None
    sort_by: str = "relevance"
    page: int = Field(default=1, ge=1)
    limit: int = Field(default=10, ge=1, le=50)


class SearchResultItem(BaseModel):
    product_id: int
    name: str
    price: float
    image: str
    score: float
    match_reason: str


class SearchData(BaseModel):
    query: str
    search_type: str
    total: int
    page: int
    limit: int
    results: list[SearchResultItem]


class SuggestionData(BaseModel):
    suggestions: list[str]


class SearchHistoryItem(BaseModel):
    query_text: str
    search_type: str
    created_at: datetime
