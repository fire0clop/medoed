# core/auth_tokens.py
from datetime import datetime, timedelta

from core.config import settings


def refresh_session_expires_at():
    return datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
