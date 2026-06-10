from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, Text, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base

class Invoice(Base):
    __tablename__ = "invoices"

    id = Column(Integer, primary_key=True, index=True)
    invoice_number = Column(String(50), unique=True, index=True)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    total_amount = Column(Float, default=0)
    discount = Column(Float, default=0)
    is_discount_percent = Column(Boolean, default=False)
    tax = Column(Float, default=0)
    final_amount = Column(Float, default=0)
    payment_method = Column(String(20), default="cash")  # cash | card | credit
    status = Column(String(20), default="completed")     # draft | completed | cancelled | refunded
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    items = relationship("InvoiceItem", back_populates="invoice", cascade="all, delete-orphan")

class InvoiceItem(Base):
    __tablename__ = "invoice_items"

    id = Column(Integer, primary_key=True, index=True)
    invoice_id = Column(Integer, ForeignKey("invoices.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    product_name = Column(String(200))
    product_barcode = Column(String(50), nullable=True)
    quantity = Column(Integer, default=1)
    unit_price = Column(Float, default=0)
    discount_percent = Column(Float, default=0)
    subtotal = Column(Float, default=0)

    invoice = relationship("Invoice", back_populates="items")
