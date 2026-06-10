from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List

class InvoiceItemCreate(BaseModel):
    product_id: int
    product_name: str
    product_barcode: Optional[str] = None
    quantity: int
    unit_price: float
    discount_percent: float = 0
    subtotal: float

class InvoiceItemResponse(InvoiceItemCreate):
    id: int
    invoice_id: int

    class Config:
        from_attributes = True

class InvoiceCreate(BaseModel):
    invoice_number: str
    customer_id: Optional[int] = None
    discount: float = 0
    is_discount_percent: bool = False
    tax: float = 0
    payment_method: str = "cash"
    notes: Optional[str] = None
    items: List[InvoiceItemCreate]

class InvoiceResponse(BaseModel):
    id: int
    invoice_number: str
    customer_id: Optional[int]
    total_amount: float
    discount: float
    final_amount: float
    payment_method: str
    status: str
    created_at: datetime
    items: List[InvoiceItemResponse] = []

    class Config:
        from_attributes = True
