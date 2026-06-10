from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, Text
from sqlalchemy.sql import func
from database import Base

class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    barcode = Column(String(50), unique=True, index=True, nullable=True)
    name = Column(String(200), nullable=False, index=True)
    category_id = Column(Integer, nullable=True)
    purchase_price = Column(Float, default=0)
    sell_price = Column(Float, default=0)
    stock_quantity = Column(Integer, default=0)
    min_stock_alert = Column(Integer, default=5)
    image_url = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
