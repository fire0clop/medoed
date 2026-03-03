# routers/auth.py

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from core.auth_tokens import refresh_session_expires_at
from core.security import create_access_token, create_refresh_token, get_current_user
from db import get_db
from models.session import Session as UserSession
from models.user import User
from schemas.auth import (
    AppleAuthRequest,
    EmailSendCodeRequest,
    EmailConfirmRegisterRequest,
    EmailLoginRequest,
    RefreshRequest,
    GoogleAuthRequest,
)
from schemas.token import TokenPair
from services.auth_apple import auth_apple
from services.auth_email import (
    send_code,
    confirm_register,
    login_email,
)
from services.auth_google import auth_google

router = APIRouter(prefix="/auth", tags=["Auth"])


# =========================
# EMAIL AUTH
# =========================


@router.post("/email/send-code")
def email_send_code(
    data: EmailSendCodeRequest,
    db: Session = Depends(get_db),
):
    try:
        send_code(db, data.email)
        return {"ok": True}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/email/confirm-register", response_model=TokenPair)
def email_confirm_register(
    data: EmailConfirmRegisterRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    try:
        return confirm_register(
            db=db,
            email=data.email,
            password=data.password,
            code=data.code,
            user_agent=request.headers.get("user-agent"),
            ip=request.client.host if request.client else None,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/email/login", response_model=TokenPair)
def email_login(
    data: EmailLoginRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    try:
        return login_email(
            db=db,
            email=data.email,
            password=data.password,
            user_agent=request.headers.get("user-agent"),
            ip=request.client.host if request.client else None,
        )
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


# =========================
# GOOGLE AUTH
# =========================


@router.post("/google", response_model=TokenPair)
def google_login(
    data: GoogleAuthRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    try:
        return auth_google(
            db=db,
            id_token_str=data.id_token,
            user_agent=request.headers.get("user-agent"),
            ip=request.client.host if request.client else None,
        )
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


# =========================
# APPLE AUTH
# =========================


@router.post("/apple", response_model=TokenPair)
def apple_login(
    data: AppleAuthRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    try:
        return auth_apple(
            db=db,
            identity_token=data.identity_token,
            user_agent=request.headers.get("user-agent"),
            ip=request.client.host if request.client else None,
        )
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))


# =========================
# REFRESH / LOGOUT
# =========================


@router.post("/refresh", response_model=TokenPair)
def refresh_token(
    data: RefreshRequest,
    db: Session = Depends(get_db),
):
    session = (
        db.query(UserSession)
        .filter(
            UserSession.refresh_token == data.refresh_token,
            UserSession.expires_at > datetime.utcnow(),
        )
        .first()
    )

    if not session:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user = db.query(User).filter(User.id == session.user_id).first()
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    new_refresh = create_refresh_token()
    session.refresh_token = new_refresh
    session.expires_at = refresh_session_expires_at()
    db.commit()

    return {
        "access_token": create_access_token(session.user_id),
        "refresh_token": new_refresh,
        "token_type": "bearer",
    }


# =========================
# DELETE ACCOUNT
# =========================


@router.delete("/account")
def delete_account(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    db.delete(current_user)
    db.commit()
    return {"ok": True}


@router.post("/logout")
def logout(
    data: RefreshRequest,
    db: Session = Depends(get_db),
):
    deleted = (
        db.query(UserSession)
        .filter(UserSession.refresh_token == data.refresh_token)
        .delete()
    )
    db.commit()

    if not deleted:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    return {"ok": True}
