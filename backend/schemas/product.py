from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class ProductBase(BaseModel):
    barcode: Optional[str] = None
    name: str
    category_id: Optional[int] = None
    purchase_price: float = 0
    sell_price: float = 0
    stock_quantity: int = 0
    min_stock_alert: int = 5
    image_url: Optional[str] = None
    is_active: bool = True

class ProductCreate(ProductBase):
    pass

class ProductUpdate(ProductBase):
    name: Optional[str] = None

class ProductResponse(ProductBase):
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
