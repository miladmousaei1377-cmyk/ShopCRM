"""
سرویس تحلیل هوشمند Claude AI
مدیریت cache، سهمیه روزانه، و فراخوانی API
"""
import json, os
from datetime import datetime, timedelta, date, timezone
from typing import Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException

from models.prediction import AiAnalysisCache, AiUsageLog
from services.prediction_service import build_sales_summary, get_sales_hash

DAILY_MANUAL_LIMIT = int(os.getenv("PREDICTION_MANUAL_LIMIT_PER_DAY", "3"))
CACHE_HOURS = int(os.getenv("PREDICTION_CACHE_HOURS", "24"))
CLAUDE_API_KEY = os.getenv("CLAUDE_API_KEY", "")
CLAUDE_MODEL = "claude-sonnet-4-6"


def _today_str() -> str:
    return date.today().isoformat()


def get_remaining_requests(db: Session, user_id: int) -> int:
    today = _today_str()
    log = db.query(AiUsageLog).filter_by(user_id=user_id, date=today).first()
    used = log.request_count if log else 0
    return max(0, DAILY_MANUAL_LIMIT - used)


def _log_usage(db: Session, user_id: int) -> None:
    today = _today_str()
    log = db.query(AiUsageLog).filter_by(user_id=user_id, date=today).first()
    if log:
        log.request_count += 1
    else:
        db.add(AiUsageLog(user_id=user_id, date=today, request_count=1))
    db.commit()


def _get_valid_cache(db: Session, user_id: int) -> Optional[AiAnalysisCache]:
    now = datetime.utcnow()
    return (
        db.query(AiAnalysisCache)
        .filter(AiAnalysisCache.expires_at > now)
        .order_by(AiAnalysisCache.created_at.desc())
        .first()
    )


def _save_cache(db: Session, user_id: int, data: dict, sales_hash: str) -> None:
    expires = datetime.utcnow() + timedelta(hours=CACHE_HOURS)
    # حذف cache قدیمی
    db.query(AiAnalysisCache).delete()
    cache = AiAnalysisCache(
        user_id=user_id,
        analysis_text=data["analysis"],
        recommendations_json=json.dumps(data["recommendations"], ensure_ascii=False),
        sales_hash=sales_hash,
        expires_at=expires,
    )
    db.add(cache)
    db.commit()
    db.refresh(cache)
    return cache


def _call_claude(sales_data: dict) -> dict:
    """فراخوانی Claude API با پرامپت داینامیک"""
    if not CLAUDE_API_KEY:
        raise HTTPException(status_code=503, detail="کلید API هوش مصنوعی تنظیم نشده است")

    try:
        import anthropic
        client = anthropic.Anthropic(api_key=CLAUDE_API_KEY)

        prompt = f"""تو یک مشاور کسب‌وکار فروشگاهی هستی. داده‌های واقعی این فروشگاه را تحلیل کن:

دوره بررسی: {sales_data['period_label']}
فروش دوره جاری: {sales_data['current_period_sales']} تومان
فروش دوره قبل: {sales_data['previous_period_sales']} تومان
تعداد فاکتور: {sales_data['invoice_count']}
میانگین فاکتور: {sales_data['avg_invoice_amount']} تومان

پرفروش‌ترین محصولات:
{sales_data['top_products']}

محصولات رو به اتمام:
{sales_data['low_stock_products']}

بهترین روز فروش: {sales_data['best_day']}
کمترین روز فروش: {sales_data['worst_day']}

بر اساس این داده‌های واقعی یک تحلیل کوتاه ۳ جمله به فارسی بنویس و سه پیشنهاد عملی مختص همین فروشگاه بده.

پاسخ فقط JSON بده:
{{
  "analysis": "متن تحلیل...",
  "recommendations": ["پیشنهاد ۱", "پیشنهاد ۲", "پیشنهاد ۳"]
}}"""

        message = client.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=1000,
            messages=[{"role": "user", "content": prompt}],
        )
        raw = message.content[0].text
        clean = raw.replace("```json", "").replace("```", "").strip()
        return json.loads(clean)

    except json.JSONDecodeError:
        return {
            "analysis": "تحلیل موقتاً در دسترس نیست.",
            "recommendations": ["لطفاً دوباره امتحان کنید."],
        }
    except ImportError:
        raise HTTPException(status_code=503, detail="کتابخانه anthropic نصب نشده است")


def get_ai_analysis(db: Session, user_id: int, period: str, force: bool) -> dict:
    """دریافت تحلیل هوشمند — با مدیریت cache و سهمیه"""
    current_hash = get_sales_hash(db)
    cached = _get_valid_cache(db, user_id)

    # cache معتبر و داده تغییر نکرده
    if cached and cached.sales_hash == current_hash and not force:
        return {
            "analysis": cached.analysis_text,
            "recommendations": json.loads(cached.recommendations_json),
            "source": "cache",
            "generated_at": cached.created_at.strftime("%Y/%m/%d %H:%M"),
            "expires_at": cached.expires_at.strftime("%Y/%m/%d %H:%M"),
            "remaining_manual_requests": get_remaining_requests(db, user_id),
        }

    # بررسی سهمیه
    remaining = get_remaining_requests(db, user_id)
    if remaining <= 0 and force:
        raise HTTPException(
            status_code=429,
            detail={
                "error": "سهمیه روزانه تمام شد",
                "message": f"شما امروز {DAILY_MANUAL_LIMIT} بار از تحلیل هوشمند استفاده کردید. فردا دوباره امتحان کنید.",
            },
        )

    # ثبت مصرف (فقط برای درخواست دستی)
    if force:
        _log_usage(db, user_id)

    # فراخوانی Claude
    sales_data = build_sales_summary(db, period)
    result = _call_claude(sales_data)

    # ذخیره cache
    cache = _save_cache(db, user_id, result, current_hash)

    return {
        **result,
        "source": "fresh",
        "generated_at": datetime.utcnow().strftime("%Y/%m/%d %H:%M"),
        "expires_at": (datetime.utcnow() + timedelta(hours=CACHE_HOURS)).strftime("%Y/%m/%d %H:%M"),
        "remaining_manual_requests": get_remaining_requests(db, user_id),
    }


def get_ai_status(db: Session, user_id: int) -> dict:
    """وضعیت سهمیه و cache"""
    cached = _get_valid_cache(db, user_id)
    remaining = get_remaining_requests(db, user_id)

    return {
        "daily_limit": DAILY_MANUAL_LIMIT,
        "used_today": DAILY_MANUAL_LIMIT - remaining,
        "remaining": remaining,
        "last_analysis_at": cached.created_at.strftime("%Y/%m/%d %H:%M") if cached else None,
        "cache_valid": cached is not None and cached.is_valid(),
        "cache_expires_at": cached.expires_at.strftime("%Y/%m/%d %H:%M") if cached else None,
    }


async def run_scheduled_analysis(db: Session) -> None:
    """تحلیل خودکار روزانه — رایگان، از سهمیه کم نمی‌شود"""
    from models.user import User
    users = db.query(User).filter(User.is_active == True).all()
    for user in users:
        try:
            current_hash = get_sales_hash(db)
            sales_data = build_sales_summary(db, "week")
            result = _call_claude(sales_data)
            _save_cache(db, user.id, result, current_hash)
        except Exception:
            pass  # خطای یک کاربر بقیه را متوقف نکند
