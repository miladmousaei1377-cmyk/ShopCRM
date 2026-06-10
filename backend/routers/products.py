"""مسیرهای API مدیریت محصولات"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from models.product import Product
from schemas.product import ProductCreate, ProductUpdate, ProductResponse

router = APIRouter(prefix="/products", tags=["products"])


@router.get("/", response_model=List[ProductResponse])
def list_products(
    skip: int = 0,
    limit: int = Query(default=100, le=500),
    search: str | None = None,
    db: Session = Depends(get_db),
):
    """لیست محصولات فعال با قابلیت جستجو در نام"""
    q = db.query(Product).filter(Product.is_active == True)
    if search:
        q = q.filter(Product.name.ilike(f"%{search}%"))
    return q.offset(skip).limit(limit).all()


@router.get("/barcode/{code}", response_model=ProductResponse)
def get_by_barcode(code: str, db: Session = Depends(get_db)):
    """پیدا کردن محصول با بارکد — برای اسکنر"""
    product = db.query(Product).filter(Product.barcode == code).first()
    if not product:
        raise HTTPException(status_code=404, detail="محصول یافت نشد")
    return product


@router.get("/{product_id}", response_model=ProductResponse)
def get_product(product_id: int, db: Session = Depends(get_db)):
    """دریافت یک محصول با شناسه"""
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="محصول یافت نشد")
    return product


@router.post("/", response_model=ProductResponse, status_code=201)
def create_product(data: ProductCreate, db: Session = Depends(get_db)):
    """ایجاد محصول جدید — بارکد نباید تکراری باشد"""
    if data.barcode:
        exists = db.query(Product).filter(Product.barcode == data.barcode).first()
        if exists:
            raise HTTPException(status_code=400, detail="این بارکد قبلاً ثبت شده")
    product = Product(**data.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@router.put("/{product_id}", response_model=ProductResponse)
def update_product(product_id: int, data: ProductUpdate, db: Session = Depends(get_db)):
    """بروزرسانی اطلاعات محصول"""
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="محصول یافت نشد")
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(product, k, v)
    db.commit()
    db.refresh(product)
    return product


@router.delete("/{product_id}", status_code=204)
def delete_product(product_id: int, db: Session = Depends(get_db)):
    """حذف نرم محصول (غیرفعال کردن)"""
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="محصول یافت نشد")
    product.is_active = False  # soft delete — داده حذف نمی‌شود
    db.commit()
