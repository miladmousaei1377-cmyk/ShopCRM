from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from models.invoice import Invoice, InvoiceItem
from models.product import Product
from schemas.invoice import InvoiceCreate, InvoiceResponse

router = APIRouter(prefix="/invoices", tags=["invoices"])

@router.get("/", response_model=List[InvoiceResponse])
def list_invoices(skip: int = 0, limit: int = 50, db: Session = Depends(get_db)):
    return db.query(Invoice).order_by(Invoice.created_at.desc()).offset(skip).limit(limit).all()

@router.get("/{invoice_id}", response_model=InvoiceResponse)
def get_invoice(invoice_id: int, db: Session = Depends(get_db)):
    inv = db.query(Invoice).filter(Invoice.id == invoice_id).first()
    if not inv:
        raise HTTPException(status_code=404, detail="فاکتور یافت نشد")
    return inv

@router.post("/", response_model=InvoiceResponse, status_code=201)
def create_invoice(data: InvoiceCreate, db: Session = Depends(get_db)):
    # محاسبه مبالغ
    total = sum(item.subtotal for item in data.items)
    discount_amount = total * data.discount / 100 if data.is_discount_percent else data.discount
    final = total - discount_amount + (total - discount_amount) * data.tax / 100

    invoice = Invoice(
        invoice_number=data.invoice_number,
        customer_id=data.customer_id,
        total_amount=total,
        discount=data.discount,
        is_discount_percent=data.is_discount_percent,
        tax=data.tax,
        final_amount=final,
        payment_method=data.payment_method,
        notes=data.notes,
        status="completed",
    )
    db.add(invoice)
    db.flush()  # id رو بگیریم

    for item_data in data.items:
        item = InvoiceItem(invoice_id=invoice.id, **item_data.model_dump())
        db.add(item)
        # کاهش موجودی
        product = db.query(Product).filter(Product.id == item_data.product_id).first()
        if product:
            product.stock_quantity = max(0, product.stock_quantity - item_data.quantity)

    db.commit()
    db.refresh(invoice)
    return invoice
