# services/auth_google.py

from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from sqlalchemy.orm import Session

from core.auth_tokens import refresh_session_expires_at
from core.config import settings
from core.profile_defaults import DEFAULT_PROFILE, ensure_profile
from core.security import create_access_token, create_refresh_token
from models.profile import Profile
from models.session import Session as UserSession
from models.user import User

def auth_google(
    db: Session,
    id_token_str: str,
    user_agent: str | None,
    ip: str | None,
):
    # ✅ verifies signature + exp + issuer
    payload = google_id_token.verify_oauth2_token(
        id_token_str,
        google_requests.Request(),
        audience=None,  # validate manually below
    )

    aud = payload.get("aud")
    allowed = set(a.strip() for a in settings.GOOGLE_ALLOWED_AUDS.split(",") if a.strip())
    if aud not in allowed:
        raise ValueError("Invalid audience")

    email = payload.get("email")
    if not email:
        raise ValueError("No email in token")

    email = email.strip().lower()

    user = db.query(User).filter(User.email == email).first()
    if not user:
        user = User(email=email, provider="google")
        db.add(user)
        db.flush()
        db.add(Profile(user_id=user.id, **DEFAULT_PROFILE))
    else:
        ensure_profile(db, user.id)

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
