"""
فروشگاه هوشمند — FastAPI Backend
نقطه ورود سرور
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from config import settings
from database import engine, Base

# ایمپورت مدل‌ها تا SQLAlchemy جداول را بشناسد
import models.user
import models.product
import models.customer
import models.invoice

from routers import auth, products, invoices, customers, reports, sync

# ─── ساخت اپلیکیشن ─────────────────────────────────────────────
app = FastAPI(
    title="فروشگاه هوشمند API",
    description="سیستم مدیریت فروشگاه — backend سرویس",
    version="1.0.0",
    # swagger فقط در محیط توسعه فعال باشد
    docs_url="/docs"   if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
)

# ─── CORS برای دسترسی کلاینت فلاتر ────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── ایجاد جداول دیتابیس در اولین اجرا ─────────────────────────
Base.metadata.create_all(bind=engine)

# ─── ثبت Router‌ها ──────────────────────────────────────────────
app.include_router(auth.router,      prefix="/api")
app.include_router(products.router,  prefix="/api")
app.include_router(invoices.router,  prefix="/api")
app.include_router(customers.router, prefix="/api")
app.include_router(reports.router,   prefix="/api")
app.include_router(sync.router,      prefix="/api")


# ─── Endpoint‌های سطح بالا ──────────────────────────────────────

@app.get("/health")
def health_check():
    """بررسی سلامت سرور (برای Docker healthcheck)"""
    return {"status": "ok", "app": "فروشگاه هوشمند"}


@app.get("/api/dashboard/summary")
def dashboard_summary():
    """خلاصه آماری داشبورد — فروش امروز، موجودی، هشدار، بدهی"""
    from database import SessionLocal
    from sqlalchemy import func
    from datetime import date

    db = SessionLocal()
    try:
        from models.invoice import Invoice
        from models.product import Product
        from models.customer import Customer

        today = date.today()

        # جمع فروش امروز
        today_sales = db.query(func.sum(Invoice.final_amount)).filter(
            func.date(Invoice.created_at) == today,
            Invoice.status == "completed",
        ).scalar() or 0

        # تعداد محصولات فعال
        product_count = db.query(func.count(Product.id)).filter(
            Product.is_active == True
        ).scalar() or 0

        # تعداد محصولات زیر حداقل موجودی
        low_stock_count = db.query(func.count(Product.id)).filter(
            Product.is_active == True,
            Product.stock_quantity <= Product.min_stock_alert,
        ).scalar() or 0

        # جمع کل بدهی مشتریان
        total_debt = db.query(func.sum(Customer.total_debt)).scalar() or 0

        return {
            "today_sales":    float(today_sales),
            "product_count":  product_count,
            "low_stock_count": low_stock_count,
            "total_debt":     float(total_debt),
        }
    finally:
        db.close()
