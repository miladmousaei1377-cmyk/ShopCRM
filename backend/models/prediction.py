"""
مدل‌های SQLAlchemy برای ماژول پیش‌بینی فروش
"""
from sqlalchemy import Column, Integer, String, Text, DateTime, Float, func
from database import Base
from datetime import datetime


class AiAnalysisCache(Base):
    __tablename__ = "ai_analysis_cache"

    id          = Column(Integer, primary_key=True, index=True)
    user_id     = Column(Integer, nullable=True)          # None = global cache
    analysis_text          = Column(Text, nullable=False)
    recommendations_json   = Column(Text, nullable=False)  # JSON array
    sales_hash  = Column(String(64), nullable=False)       # MD5 of data snapshot
    created_at  = Column(DateTime, default=datetime.utcnow)
    expires_at  = Column(DateTime, nullable=False)

    def is_valid(self) -> bool:
        return datetime.utcnow() < self.expires_at


class AiUsageLog(Base):
    __tablename__ = "ai_usage_log"

    id            = Column(Integer, primary_key=True, index=True)
    user_id       = Column(Integer, nullable=False)
    date          = Column(String(10), nullable=False)   # YYYY-MM-DD
    request_count = Column(Integer, default=0)
