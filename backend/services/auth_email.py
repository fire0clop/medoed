# services/auth_email.py
import random
import smtplib
import ssl
import time
from datetime import datetime, timedelta
from email.message import EmailMessage

from sqlalchemy.orm import Session

from core.auth_tokens import refresh_session_expires_at
from core.config import settings
from core.profile_defaults import DEFAULT_PROFILE
from core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_password,
)
from models.profile import Profile
from models.session import Session as UserSession
from models.user import User

_codes: dict[str, str] = {}
_last_send_at: dict[str, float] = {}
CODE_RESEND_SECONDS = 60


def _normalize_email(email: str) -> str:
    return email.strip().lower()


# =========================
# REGISTRATION
# =========================


def send_code(db: Session, email: str):
    email = _normalize_email(email)
    existing = db.query(User).filter(User.email == email).first()
    if existing:
        raise ValueError("User already exists")

    now = time.time()
    last = _last_send_at.get(email, 0)
    if now - last < CODE_RESEND_SECONDS:
        wait = int(CODE_RESEND_SECONDS - (now - last))
        raise ValueError(f"Please wait {wait} seconds before requesting another code")

    code = str(random.randint(100000, 999999))
    _codes[email] = code
    _last_send_at[email] = now

    msg = EmailMessage()
    msg["From"] = settings.FROM_EMAIL
    msg["To"] = email
    msg["Subject"] = "DiabetAI – код подтверждения"
    msg.set_content(f"Ваш код подтверждения: {code}")

    context = ssl.create_default_context()
    with smtplib.SMTP_SSL(settings.SMTP_HOST, settings.SMTP_PORT, context=context) as s:
        s.login(settings.SMTP_USER, settings.SMTP_PASS)
        s.send_message(msg)


def confirm_register(
    db: Session,
    email: str,
    password: str,
    code: str,
    user_agent: str | None,
    ip: str | None,
):
    email = _normalize_email(email)
    if _codes.get(email) != code:
        raise ValueError("Invalid confirmation code")

    existing = db.query(User).filter(User.email == email).first()
    if existing:
        raise ValueError("User already exists")

    user = User(
        email=email,
        hashed_password=hash_password(password),
        provider="email",
    )
    db.add(user)
    db.flush()

    db.add(Profile(user_id=user.id, **DEFAULT_PROFILE))

    refresh = create_refresh_token()
    db.add(
        UserSession(
            user_id=user.id,
            refresh_token=refresh,
            user_agent=user_agent,
            ip_address=ip,
            expires_at=refresh_session_expires_at(),
        )
    )

    db.commit()
    _codes.pop(email, None)

    return {
        "access_token": create_access_token(user.id),
        "refresh_token": refresh,
        "token_type": "bearer",
    }


# =========================
# LOGIN
# =========================


def login_email(
    db: Session,
    email: str,
    password: str,
    user_agent: str | None,
    ip: str | None,
):
    email = _normalize_email(email)
    user = db.query(User).filter(User.email == email).first()

    if not user or not user.hashed_password:
        raise ValueError("Invalid credentials")

    if not verify_password(password, user.hashed_password):
        raise ValueError("Invalid credentials")

    if not user.is_active:
        raise ValueError("Account is inactive")

    refresh = create_refresh_token()
    db.add(
        UserSession(
            user_id=user.id,
            refresh_token=refresh,
            user_agent=user_agent,
            ip_address=ip,
            expires_at=refresh_session_expires_at(),
        )
    )

    db.commit()

    return {
        "access_token": create_access_token(user.id),
        "refresh_token": refresh,
        "token_type": "bearer",
    }
