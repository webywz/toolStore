from pydantic import BaseModel


class FavoriteProductItem(BaseModel):
    id: int
    name: str
    price: float
    image: str


class FavoriteListData(BaseModel):
    total: int
    products: list[FavoriteProductItem]
