"""
سرویس احراز هویت
مدیریت رمزعبور، توکن JWT و بررسی هویت کاربر
"""
from datetime import datetime, timedelta
from jose import jwt, JWTError
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from models.user import User
from config import settings

# ─── هش رمزعبور ─────────────────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """تبدیل رمزعبور ساده به هش bcrypt"""
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    """تطابق رمزعبور وارد شده با هش ذخیره شده"""
    return pwd_context.verify(plain, hashed)


# ─── JWT Tokens ──────────────────────────────────────────────────

def create_access_token(data: dict) -> str:
    """ساخت Access Token با انقضای کوتاه (۲۴ ساعت)"""
    payload = data.copy()
    payload["exp"] = datetime.utcnow() + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token(data: dict) -> str:
    """ساخت Refresh Token با انقضای بلند (۳۰ روز)"""
    payload = data.copy()
    payload["exp"] = datetime.utcnow() + timedelta(
        days=settings.REFRESH_TOKEN_EXPIRE_DAYS
    )
    payload["type"] = "refresh"  # برای تمایز از access token
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str) -> dict | None:
    """رمزگشایی توکن — None اگر نامعتبر یا منقضی باشد"""
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError:
        return None


# ─── احراز هویت ──────────────────────────────────────────────────

def authenticate_user(db: Session, username: str, password: str) -> User | None:
    """بررسی نام کاربری و رمزعبور — None اگر اشتباه باشد"""
    user = db.query(User).filter(User.username == username).first()
    if not user or not verify_password(password, user.hashed_password):
        return None
    return user


def get_current_user(db: Session, token: str) -> User | None:
    """استخراج کاربر از توکن — برای middleware احراز هویت"""
    payload = decode_token(token)
    if not payload:
        return None
    username = payload.get("sub")
    if not username:
        return None
    return db.query(User).filter(User.username == username).first()
