"""مسیرهای گزارش‌گیری فروش"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import date
from database import get_db
from models.invoice import Invoice, InvoiceItem
from models.product import Product

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/daily")
def daily_report(db: Session = Depends(get_db)):
    """گزارش فروش امروز"""
    today = date.today()
    invoices = db.query(Invoice).filter(
        func.date(Invoice.created_at) == today,
        Invoice.status == "completed",
    ).all()
    total = sum(i.final_amount for i in invoices)
    return {
        "date":          today.isoformat(),
        "total_sales":   total,
        "invoice_count": len(invoices),
    }


@router.get("/period")
def period_report(
    from_date: date = Query(..., description="تاریخ شروع (YYYY-MM-DD)"),
    to_date:   date = Query(..., description="تاریخ پایان (YYYY-MM-DD)"),
    db: Session = Depends(get_db),
):
    """گزارش فروش یک بازه زمانی"""
    invoices = db.query(Invoice).filter(
        func.date(Invoice.created_at) >= from_date,
        func.date(Invoice.created_at) <= to_date,
        Invoice.status == "completed",
    ).all()
    total = sum(i.final_amount for i in invoices)
    return {
        "from":          from_date.isoformat(),
        "to":            to_date.isoformat(),
        "total_sales":   total,
        "invoice_count": len(invoices),
    }


@router.get("/top-products")
def top_products(
    from_date: date | None = Query(None, description="تاریخ شروع"),
    to_date:   date | None = Query(None, description="تاریخ پایان"),
    limit: int = Query(10, description="تعداد محصولات"),
    db: Session = Depends(get_db),
):
    """پرفروش‌ترین محصولات — مرتب‌شده بر اساس درآمد"""
    q = (
        db.query(
            InvoiceItem.product_id,
            InvoiceItem.product_name,
            func.sum(InvoiceItem.quantity).label("total_quantity"),
            func.sum(InvoiceItem.subtotal).label("total_revenue"),
        )
        .join(Invoice)
        .filter(Invoice.status == "completed")
    )
    # فیلتر بازه زمانی (اختیاری)
    if from_date:
        q = q.filter(func.date(Invoice.created_at) >= from_date)
    if to_date:
        q = q.filter(func.date(Invoice.created_at) <= to_date)

    results = (
        q.group_by(InvoiceItem.product_id, InvoiceItem.product_name)
        .order_by(func.sum(InvoiceItem.subtotal).desc()) # بیشترین فروش اول
        .limit(limit)
        .all()
    )
    return [
        {
            "product_id":    r.product_id,
            "product_name":  r.product_name,
            "total_quantity": r.total_quantity,
            "total_revenue": float(r.total_revenue),
        }
        for r in results
    ]
