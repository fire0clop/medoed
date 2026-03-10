# services/auth_apple.py
import json
import time
import urllib.request

import jwt as pyjwt
from jwt.algorithms import ECAlgorithm, RSAAlgorithm
from jwt.exceptions import PyJWTError
from sqlalchemy.orm import Session

from core.auth_tokens import refresh_session_expires_at
from core.config import settings
from core.profile_defaults import DEFAULT_PROFILE, ensure_profile
from core.security import create_access_token, create_refresh_token
from models.session import Session as UserSession
from models.user import User
from models.profile import Profile

_jwks_cache: dict = {}
_jwks_fetched_at: float = 0.0
_JWKS_TTL = 3600.0


def _get_apple_public_key(identity_token: str):
    global _jwks_cache, _jwks_fetched_at
    now = time.monotonic()
    if not _jwks_cache or (now - _jwks_fetched_at) > _JWKS_TTL:
        with urllib.request.urlopen("https://appleid.apple.com/auth/keys", timeout=10) as resp:
            _jwks_cache = json.loads(resp.read())
        _jwks_fetched_at = now

    header = pyjwt.get_unverified_header(identity_token)
    kid = header.get("kid")
    alg = header.get("alg", "ES256")

    for key_data in _jwks_cache.get("keys", []):
        if key_data.get("kid") == kid:
            if alg.startswith("RS"):
                return RSAAlgorithm.from_jwk(key_data), alg
            else:
                return ECAlgorithm.from_jwk(key_data), alg

    _jwks_cache = {}
    raise PyJWTError(f"Apple signing key not found: kid={kid}")


def auth_apple(
    db: Session,
    identity_token: str,
    user_agent: str | None,
    ip: str | None,
):
    try:
        public_key, alg = _get_apple_public_key(identity_token)
        payload = pyjwt.decode(
            identity_token,
            public_key,
            algorithms=[alg],
            audience=settings.APPLE_BUNDLE_ID,
            issuer="https://appleid.apple.com",
        )
    except Exception as e:
        print(f"APPLE AUTH ERROR: {type(e).__name__}: {e}", flush=True)
        raise ValueError("Invalid Apple identity token") from e

    print(f"APPLE JWT OK: sub={payload.get('sub')}, email={payload.get('email')}", flush=True)
    sub = payload.get("sub")
    if not sub or not isinstance(sub, str):
        raise ValueError("Invalid token: missing sub")

    email_raw = payload.get("email")
    email = email_raw.strip().lower() if isinstance(email_raw, str) and email_raw.strip() else None

    user = db.query(User).filter(User.apple_sub == sub).first()

    if not user:
        if email:
            existing = db.query(User).filter(User.email == email).first()
            if existing:
                if existing.provider != "apple":
                    raise ValueError("Email already registered with another sign-in method")
                if existing.apple_sub and existing.apple_sub != sub:
                    raise ValueError("Apple account conflict")
                existing.apple_sub = sub
                user = existing
            else:
                user = User(email=email, provider="apple", apple_sub=sub)
                db.add(user)
                db.flush()
                db.add(Profile(user_id=user.id, **DEFAULT_PROFILE))
        else:
            user = User(email=None, provider="apple", apple_sub=sub)
            db.add(user)
            db.flush()
            db.add(Profile(user_id=user.id, **DEFAULT_PROFILE))

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
