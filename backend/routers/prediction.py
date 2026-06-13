"""
Router پیش‌بینی فروش
endpoints: /api/prediction/*
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from database import get_db
from schemas.prediction import (
    SalesForecastResponse, StockAlertResponse, TopProductsResponse,
    AiAnalysisRequest, AiAnalysisResponse, AiStatusResponse,
)
from services import prediction_service, ai_service

router = APIRouter(prefix="/prediction", tags=["prediction"])

# مقدار پیش‌فرض user_id — در نسخه با auth از token می‌آید
DEFAULT_USER_ID = 1


@router.get("/daily", response_model=SalesForecastResponse)
def get_sales_forecast(
    days: int = Query(default=30, ge=7, le=90),
    db: Session = Depends(get_db),
):
    """پیش‌بینی فروش روزانه (Prophet یا میانگین متحرک)"""
    result = prediction_service.predict_sales(db, days=days)
    sales_data = prediction_service._get_daily_sales(db, days=90)

    trend = prediction_service.get_trend(sales_data)
    best_day, worst_day = prediction_service.get_best_worst_day(sales_data)

    return SalesForecastResponse(
        predictions=result["predictions"],
        trend=trend,
        best_day_of_week=best_day,
        worst_day_of_week=worst_day,
        data_source=result["source"],
        data_points=len(sales_data),
    )


@router.get("/stock-alert", response_model=StockAlertResponse)
def get_stock_alerts(db: Session = Depends(get_db)):
    """هشدار موجودی محصولات رو به اتمام"""
    alerts = prediction_service.get_stock_alerts(db)
    return StockAlertResponse(alerts=alerts, total_alerts=len(alerts))


@router.get("/top-products", response_model=TopProductsResponse)
def get_top_products(db: Session = Depends(get_db)):
    """پیش‌بینی پرفروش‌ترین محصولات هفته آینده"""
    result = prediction_service.get_top_products_next_week(db)
    return TopProductsResponse(**result)


@router.post("/ai-analysis", response_model=AiAnalysisResponse)
def get_ai_analysis(
    request: AiAnalysisRequest,
    db: Session = Depends(get_db),
):
    """درخواست تحلیل هوشمند Claude"""
    return ai_service.get_ai_analysis(
        db=db,
        user_id=DEFAULT_USER_ID,
        period=request.period,
        force=request.force,
    )


@router.get("/ai-status", response_model=AiStatusResponse)
def get_ai_status(db: Session = Depends(get_db)):
    """وضعیت سهمیه تحلیل هوشمند"""
    return ai_service.get_ai_status(db=db, user_id=DEFAULT_USER_ID)
