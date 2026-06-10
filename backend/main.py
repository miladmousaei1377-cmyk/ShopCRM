from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from config import settings
from database import engine, Base

# Import all models to create tables
import models.user
import models.product
import models.customer
import models.invoice

from routers import auth, products, invoices, customers, reports, sync

app = FastAPI(
    title="فروشگاه هوشمند API",
    description="سیستم مدیریت فروشگاه - backend",
    version="1.0.0",
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ایجاد جداول
Base.metadata.create_all(bind=engine)

# ثبت routers
app.include_router(auth.router, prefix="/api")
app.include_router(products.router, prefix="/api")
app.include_router(invoices.router, prefix="/api")
app.include_router(customers.router, prefix="/api")
app.include_router(reports.router, prefix="/api")
app.include_router(sync.router, prefix="/api")

@app.get("/health")
def health():
    return {"status": "ok", "app": "فروشگاه هوشمند"}

@app.get("/api/dashboard/summary")
def dashboard_summary(db=None):
    from database import SessionLocal
    from sqlalchemy import func
    from datetime import date
    db = SessionLocal()
    try:
        from models.invoice import Invoice
        from models.product import Product
        from models.customer import Customer

        today = date.today()
        today_sales = db.query(func.sum(Invoice.final_amount)).filter(
            func.date(Invoice.created_at) == today,
            Invoice.status == "completed",
        ).scalar() or 0

        product_count = db.query(func.count(Product.id)).filter(Product.is_active == True).scalar() or 0
        low_stock_count = db.query(func.count(Product.id)).filter(
            Product.is_active == True,
            Product.stock_quantity <= Product.min_stock_alert,
        ).scalar() or 0
        total_debt = db.query(func.sum(Customer.total_debt)).scalar() or 0

        return {
            "today_sales": float(today_sales),
            "product_count": product_count,
            "low_stock_count": low_stock_count,
            "total_debt": float(total_debt),
        }
    finally:
        db.close()
