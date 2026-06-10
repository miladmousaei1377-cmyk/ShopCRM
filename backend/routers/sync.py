from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Any
from database import get_db
from models.product import Product
from models.customer import Customer
from models.invoice import Invoice

router = APIRouter(prefix="/sync", tags=["sync"])

class SyncPushRequest(BaseModel):
    products: List[dict] = []
    customers: List[dict] = []
    invoices: List[dict] = []
    timestamp: str

@router.post("/push")
def push_changes(req: SyncPushRequest, db: Session = Depends(get_db)):
    """آپلود تغییرات آفلاین کلاینت به سرور"""
    synced = {"products": 0, "customers": 0, "invoices": 0}

    for p_data in req.products:
        server_id = p_data.pop("server_id", None)
        p_data.pop("id", None)  # ID محلی را حذف کن
        if server_id:
            existing = db.query(Product).filter(Product.id == server_id).first()
            if existing:
                for k, v in p_data.items():
                    if hasattr(existing, k):
                        setattr(existing, k, v)
        else:
            db.add(Product(**{k: v for k, v in p_data.items() if hasattr(Product, k)}))
        synced["products"] += 1

    db.commit()
    return {"status": "ok", "synced": synced}

@router.get("/pull")
def pull_changes(since: str | None = None, db: Session = Depends(get_db)):
    """دریافت تغییرات سرور از زمان مشخص"""
    from datetime import datetime
    if since:
        since_dt = datetime.fromisoformat(since)
        products = db.query(Product).filter(Product.updated_at > since_dt).all()
        customers = db.query(Customer).filter(Customer.updated_at > since_dt).all()
    else:
        products = db.query(Product).all()
        customers = db.query(Customer).all()

    return {
        "products": [
            {
                "id": p.id,
                "barcode": p.barcode,
                "name": p.name,
                "sell_price": p.sell_price,
                "purchase_price": p.purchase_price,
                "stock_quantity": p.stock_quantity,
                "updated_at": p.updated_at.isoformat() if p.updated_at else None,
            }
            for p in products
        ],
        "customers": [
            {
                "id": c.id,
                "name": c.name,
                "phone": c.phone,
                "total_debt": c.total_debt,
                "updated_at": c.updated_at.isoformat() if c.updated_at else None,
            }
            for c in customers
        ],
        "timestamp": datetime.utcnow().isoformat(),
    }
