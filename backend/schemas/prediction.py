"""
Pydantic schemas برای ماژول پیش‌بینی فروش
"""
from pydantic import BaseModel
from typing import List, Optional, Literal
from datetime import datetime


class DailyPrediction(BaseModel):
    date: str
    predicted_amount: float
    confidence_low: float
    confidence_high: float


class SalesForecastResponse(BaseModel):
    predictions: List[DailyPrediction]
    trend: Literal["rising", "falling", "stable"]
    best_day_of_week: str
    worst_day_of_week: str
    data_source: Literal["prophet", "moving_average"]
    data_points: int


class StockAlertItem(BaseModel):
    product_id: int
    product_name: str
    current_stock: float
    daily_avg_sales: float
    days_remaining: float
    urgency: Literal["critical", "warning", "info"]


class StockAlertResponse(BaseModel):
    alerts: List[StockAlertItem]
    total_alerts: int


class TopProductItem(BaseModel):
    product_id: int
    product_name: str
    predicted_sales: float
    trend_percent: float
    trend_label: str


class TopProductsResponse(BaseModel):
    next_week_tops: List[TopProductItem]
    data_available: bool
    message: Optional[str] = None


class AiAnalysisRequest(BaseModel):
    period: Literal["week", "month"] = "week"
    force: bool = False


class AiAnalysisResponse(BaseModel):
    analysis: str
    recommendations: List[str]
    source: Literal["cache", "fresh"]
    generated_at: str
    expires_at: str
    remaining_manual_requests: int


class AiStatusResponse(BaseModel):
    daily_limit: int
    used_today: int
    remaining: int
    last_analysis_at: Optional[str]
    cache_valid: bool
    cache_expires_at: Optional[str]
