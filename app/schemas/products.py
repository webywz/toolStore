from datetime import datetime

from pydantic import BaseModel


class ProductListItem(BaseModel):
    id: int
    name: str
    price: float
    images: list[str]
    category: str
    compatibility: list[str]


class ProductListData(BaseModel):
    total: int
    page: int
    limit: int
    products: list[ProductListItem]


class ProductDetailData(BaseModel):
    id: int
    name: str
    category_id: int
    brand: str
    model: str
    category: str
    price: float
    images: list[str]
    description: str
    specs: dict[str, str]
    compatibility: list[str]
    usage_scenarios: str
    safety_tips: list[str]
    keywords: list[str]
    created_at: datetime


class CategoryChild(BaseModel):
    id: int
    name: str
    icon_url: str | None = None


class CategoryTreeNode(BaseModel):
    id: int
    name: str
    icon_url: str | None = None
    children: list[CategoryChild]
