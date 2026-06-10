"""
مسیرهای همگام‌سازی آفلاین/آنلاین

جریان کار:
  کلاینت آفلاین کار می‌کند → تغییرات در صف pending
  وقتی آنلاین شد:
    POST /api/sync/push  ← آپلود تغییرات محلی به سرور
    GET  /api/sync/pull  ← دریافت تغییرات سرور از زمان مشخص
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List
from database import get_db
from models.product import Product
from models.customer import Customer

router = APIRouter(prefix="/sync", tags=["sync"])


class SyncPushRequest(BaseModel):
    products: List[dict] = []   # محصولات تغییر کرده
    customers: List[dict] = []  # مشتریان تغییر کرده
    invoices: List[dict] = []   # فاکتورهای جدید
    timestamp: str              # زمان درخواست


@router.post("/push")
def push_changes(req: SyncPushRequest, db: Session = Depends(get_db)):
    """
    آپلود تغییرات آفلاین کلاینت به سرور

    هر رکورد یا server_id دارد (موجود در سرور → update)
    یا ندارد (جدید → insert)
    """
    synced = {"products": 0, "customers": 0, "invoices": 0}

    # ─── همگام‌سازی محصولات ────────────────────────────────────
    for p_data in req.products:
        server_id = p_data.pop("server_id", None)
        p_data.pop("id", None)  # شناسه محلی را نادیده بگیر
        if server_id:
            # محصول موجود → بروزرسانی
            existing = db.query(Product).filter(Product.id == server_id).first()
            if existing:
                for k, v in p_data.items():
                    if hasattr(existing, k):
                        setattr(existing, k, v)
        else:
            # محصول جدید → درج
            db.add(Product(**{k: v for k, v in p_data.items()
                              if hasattr(Product, k)}))
        synced["products"] += 1

    db.commit()
    return {"status": "ok", "synced": synced}


@router.get("/pull")
def pull_changes(since: str | None = None, db: Session = Depends(get_db)):
    """
    دریافت تغییرات سرور از زمان مشخص

    [since]: ISO 8601 timestamp آخرین sync موفق
    اگر None باشد → همه رکوردها برمی‌گردد (اولین sync)
    """
    from datetime import datetime

    if since:
        # فقط تغییرات جدیدتر از آخرین sync
        since_dt = datetime.fromisoformat(since)
        products  = db.query(Product).filter(Product.updated_at > since_dt).all()
        customers = db.query(Customer).filter(Customer.updated_at > since_dt).all()
    else:
        # همه داده‌ها (sync اول)
        products  = db.query(Product).all()
        customers = db.query(Customer).all()

    return {
        "products": [
            {
                "id":             p.id,
                "barcode":        p.barcode,
                "name":           p.name,
                "sell_price":     p.sell_price,
                "purchase_price": p.purchase_price,
                "stock_quantity": p.stock_quantity,
                "updated_at":     p.updated_at.isoformat() if p.updated_at else None,
            }
            for p in products
        ],
        "customers": [
            {
                "id":         c.id,
                "name":       c.name,
                "phone":      c.phone,
                "total_debt": c.total_debt,
                "updated_at": c.updated_at.isoformat() if c.updated_at else None,
            }
            for c in customers
        ],
        "timestamp": datetime.utcnow().isoformat(), # زمان این پاسخ برای sync بعدی
    }
