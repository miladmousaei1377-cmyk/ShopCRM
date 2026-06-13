"""
سرویس پیش‌بینی فروش
ابتدا Prophet امتحان می‌کند، در صورت عدم وجود به moving average برمی‌گردد.
تمام داده‌ها به‌صورت داینامیک از دیتابیس خوانده می‌شوند.
"""
import json, hashlib
from datetime import datetime, timedelta, date
from typing import List, Dict, Any, Optional
from collections import defaultdict
from sqlalchemy.orm import Session
from sqlalchemy import func, cast, Date


def _get_daily_sales(db: Session, days: int = 90) -> List[Dict]:
    """دریافت فروش روزانه از دیتابیس (کاملاً داینامیک)"""
    from models.invoice import Invoice
    since = datetime.utcnow() - timedelta(days=days)

    rows = (
        db.query(
            cast(Invoice.created_at, Date).label("sale_date"),
            func.sum(Invoice.final_amount).label("total"),
        )
        .filter(Invoice.created_at >= since)
        .filter(Invoice.status == "completed")
        .group_by(cast(Invoice.created_at, Date))
        .order_by(cast(Invoice.created_at, Date))
        .all()
    )
    return [{"date": str(r.sale_date), "amount": float(r.total or 0)} for r in rows]


def _moving_average_predict(sales_data: List[Dict], days: int = 30) -> Dict:
    """پیش‌بینی با میانگین متحرک ۷ روزه — کاملاً آفلاین"""
    values = [s["amount"] for s in sales_data]
    if not values:
        values = [0]

    window = min(7, len(values))
    avg = sum(values[-window:]) / window
    std = 0.0
    if window > 1:
        variance = sum((v - avg) ** 2 for v in values[-window:]) / window
        std = variance ** 0.5

    predictions = []
    base = date.today()
    for i in range(1, days + 1):
        d = base + timedelta(days=i)
        predictions.append({
            "date": d.isoformat(),
            "predicted_amount": round(avg, 0),
            "confidence_low": round(max(0, avg - std * 1.5), 0),
            "confidence_high": round(avg + std * 1.5, 0),
        })
    return {"predictions": predictions, "source": "moving_average"}


def predict_sales(db: Session, days: int = 30) -> Dict:
    """پیش‌بینی فروش — Prophet اگر موجود باشد، وگرنه moving average"""
    sales_data = _get_daily_sales(db, days=90)

    if len(sales_data) >= 7:
        try:
            import pandas as pd
            from prophet import Prophet

            df = pd.DataFrame({
                "ds": pd.to_datetime([s["date"] for s in sales_data]),
                "y": [s["amount"] for s in sales_data],
            })
            model = Prophet(
                yearly_seasonality=False,
                weekly_seasonality=True,
                daily_seasonality=False,
                changepoint_prior_scale=0.05,
                uncertainty_samples=100,
            )
            model.fit(df)
            future = model.make_future_dataframe(periods=days)
            forecast = model.predict(future)
            future_fc = forecast.tail(days)

            predictions = [
                {
                    "date": row["ds"].date().isoformat(),
                    "predicted_amount": round(max(0, row["yhat"]), 0),
                    "confidence_low": round(max(0, row["yhat_lower"]), 0),
                    "confidence_high": round(max(0, row["yhat_upper"]), 0),
                }
                for _, row in future_fc.iterrows()
            ]
            return {"predictions": predictions, "source": "prophet"}
        except Exception:
            pass  # Prophet موجود نیست یا خطا داد → fallback

    return _moving_average_predict(sales_data, days)


def get_trend(sales_data: List[Dict]) -> str:
    """تعیین روند کلی فروش"""
    if len(sales_data) < 4:
        return "stable"
    half = len(sales_data) // 2
    first_avg = sum(s["amount"] for s in sales_data[:half]) / half
    second_avg = sum(s["amount"] for s in sales_data[half:]) / half
    if first_avg == 0:
        return "stable"
    change = (second_avg - first_avg) / first_avg
    if change > 0.05:
        return "rising"
    if change < -0.05:
        return "falling"
    return "stable"


_PERSIAN_WEEKDAYS = {
    0: "دوشنبه", 1: "سه‌شنبه", 2: "چهارشنبه",
    3: "پنجشنبه", 4: "جمعه", 5: "شنبه", 6: "یکشنبه",
}


def get_best_worst_day(sales_data: List[Dict]) -> tuple[str, str]:
    """بهترین و بدترین روز هفته از نظر فروش"""
    day_totals: Dict[int, float] = defaultdict(float)
    day_counts: Dict[int, int] = defaultdict(int)

    for s in sales_data:
        d = date.fromisoformat(s["date"])
        day_totals[d.weekday()] += s["amount"]
        day_counts[d.weekday()] += 1

    if not day_totals:
        return "—", "—"

    avgs = {k: day_totals[k] / day_counts[k] for k in day_totals}
    best = max(avgs, key=avgs.get)
    worst = min(avgs, key=avgs.get)
    return _PERSIAN_WEEKDAYS.get(best, "—"), _PERSIAN_WEEKDAYS.get(worst, "—")


def get_stock_alerts(db: Session) -> List[Dict]:
    """هشدار موجودی — کاملاً داینامیک از دیتابیس"""
    from models.product import Product
    from models.invoice import Invoice, InvoiceItem

    thirty_days_ago = datetime.utcnow() - timedelta(days=30)

    # میانگین روزانه فروش هر محصول
    sales_rows = (
        db.query(
            InvoiceItem.product_id,
            func.sum(InvoiceItem.quantity).label("total_qty"),
        )
        .join(Invoice, Invoice.id == InvoiceItem.invoice_id)
        .filter(Invoice.created_at >= thirty_days_ago)
        .filter(Invoice.status == "completed")
        .group_by(InvoiceItem.product_id)
        .all()
    )
    avg_daily: Dict[int, float] = {r.product_id: r.total_qty / 30.0 for r in sales_rows}

    products = db.query(Product).filter(Product.is_active == True).all()
    alerts = []
    for p in products:
        daily = avg_daily.get(p.id, 0)
        if daily <= 0:
            continue
        days_left = p.stock_quantity / daily
        if days_left > 7:
            continue
        urgency = "critical" if days_left <= 2 else ("warning" if days_left <= 5 else "info")
        alerts.append({
            "product_id": p.id,
            "product_name": p.name,
            "current_stock": p.stock_quantity,
            "daily_avg_sales": round(daily, 1),
            "days_remaining": round(days_left, 1),
            "urgency": urgency,
        })

    return sorted(alerts, key=lambda x: x["days_remaining"])


def get_top_products_next_week(db: Session) -> Dict:
    """پیش‌بینی پرفروش‌ترین محصولات هفته آینده"""
    from models.invoice import Invoice, InvoiceItem
    from models.product import Product

    now = datetime.utcnow()
    this_week_start = now - timedelta(days=7)
    prev_week_start = now - timedelta(days=14)

    def _week_sales(start, end):
        rows = (
            db.query(
                InvoiceItem.product_id,
                InvoiceItem.product_name,
                func.sum(InvoiceItem.quantity).label("qty"),
                func.sum(InvoiceItem.subtotal).label("revenue"),
            )
            .join(Invoice, Invoice.id == InvoiceItem.invoice_id)
            .filter(Invoice.created_at >= start)
            .filter(Invoice.created_at < end)
            .filter(Invoice.status == "completed")
            .group_by(InvoiceItem.product_id, InvoiceItem.product_name)
            .order_by(func.sum(InvoiceItem.revenue).desc())
            .limit(5)
            .all()
        )
        return {r.product_id: {"name": r.product_name, "qty": float(r.qty or 0), "revenue": float(r.revenue or 0)} for r in rows}

    current = _week_sales(this_week_start, now)
    previous = _week_sales(prev_week_start, this_week_start)

    if not current:
        return {"next_week_tops": [], "data_available": False, "message": "داده کافی برای پیش‌بینی وجود ندارد"}

    tops = []
    for pid, data in current.items():
        prev_qty = previous.get(pid, {}).get("qty", 0)
        if prev_qty > 0:
            trend_pct = (data["qty"] - prev_qty) / prev_qty * 100
        else:
            trend_pct = 100.0

        sign = "+" if trend_pct >= 0 else ""
        tops.append({
            "product_id": pid,
            "product_name": data["name"],
            "predicted_sales": round(data["qty"] * 1.05, 1),  # پیش‌بینی هفته آینده ≈ +۵٪
            "trend_percent": round(trend_pct, 1),
            "trend_label": f"{sign}{round(trend_pct,0):.0f}٪ نسبت به هفته قبل",
        })

    return {"next_week_tops": tops, "data_available": True}


def build_sales_summary(db: Session, period: str) -> Dict:
    """ساخت خلاصه فروش برای ارسال به Claude (کاملاً داینامیک)"""
    from models.invoice import Invoice, InvoiceItem

    days = 7 if period == "week" else 30
    now = datetime.utcnow()
    curr_start = now - timedelta(days=days)
    prev_start = now - timedelta(days=days * 2)

    def _period_stats(start, end):
        rows = (
            db.query(
                func.sum(Invoice.final_amount).label("total"),
                func.count(Invoice.id).label("count"),
                func.avg(Invoice.final_amount).label("avg"),
            )
            .filter(Invoice.created_at >= start)
            .filter(Invoice.created_at < end)
            .filter(Invoice.status == "completed")
            .first()
        )
        return {
            "total": float(rows.total or 0),
            "count": int(rows.count or 0),
            "avg": float(rows.avg or 0),
        }

    curr = _period_stats(curr_start, now)
    prev = _period_stats(prev_start, curr_start)

    # پرفروش‌ترین محصولات
    top_rows = (
        db.query(
            InvoiceItem.product_name,
            func.sum(InvoiceItem.quantity).label("qty"),
        )
        .join(Invoice, Invoice.id == InvoiceItem.invoice_id)
        .filter(Invoice.created_at >= curr_start)
        .filter(Invoice.status == "completed")
        .group_by(InvoiceItem.product_name)
        .order_by(func.sum(InvoiceItem.quantity).desc())
        .limit(5)
        .all()
    )
    top_products = "\n".join(f"- {r.product_name}: {int(r.qty)} عدد" for r in top_rows) or "اطلاعاتی موجود نیست"

    # محصولات رو به اتمام
    alerts = get_stock_alerts(db)[:3]
    low_stock = "\n".join(
        f"- {a['product_name']}: {a['days_remaining']} روز دیگر تمام می‌شود"
        for a in alerts
    ) or "همه محصولات موجودی کافی دارند"

    # بهترین/بدترین روز
    sales_data = _get_daily_sales(db, days=30)
    best_day, worst_day = get_best_worst_day(sales_data)

    return {
        "period_label": "۷ روز اخیر" if period == "week" else "۳۰ روز اخیر",
        "current_period_sales": f"{curr['total']:,.0f}",
        "previous_period_sales": f"{prev['total']:,.0f}",
        "invoice_count": curr["count"],
        "avg_invoice_amount": f"{curr['avg']:,.0f}",
        "top_products": top_products,
        "low_stock_products": low_stock,
        "best_day": best_day,
        "worst_day": worst_day,
    }


def get_sales_hash(db: Session) -> str:
    """هش داده‌های فروش برای تشخیص تغییر"""
    sales_data = _get_daily_sales(db, days=7)
    data_str = json.dumps(sales_data, sort_keys=True)
    return hashlib.md5(data_str.encode()).hexdigest()
