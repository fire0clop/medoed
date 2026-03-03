# routers/profile.py
import os
import secrets

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session

from core.profile_defaults import ensure_profile
from core.security import get_current_user
from db import get_db
from models.profile import Profile
from models.user import User
from schemas.profile import ProfileResponse, ProfileUpdateRequest

router = APIRouter(prefix="/profile", tags=["Profile"])

# === Аватары ===
# Каталог хранения внутри приложения; отдаётся через StaticFiles (mount /uploads в main.py).
APP_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AVATAR_DIR = os.path.join(APP_ROOT, "uploads", "avatars")
ALLOWED_TYPES = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}
MAX_AVATAR_BYTES = 5 * 1024 * 1024  # 5 МБ


def _remove_avatar_file(avatar_url: str | None) -> None:
    if not avatar_url:
        return
    path = os.path.join(APP_ROOT, avatar_url.lstrip("/"))
    # защита от выхода за пределы каталога аватаров
    if os.path.commonpath([os.path.abspath(path), AVATAR_DIR]) != AVATAR_DIR:
        return
    try:
        os.remove(path)
    except OSError:
        pass


@router.get("", response_model=ProfileResponse)
def get_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = ensure_profile(db, current_user.id)
    db.commit()
    db.refresh(profile)
    return profile


@router.put("", response_model=ProfileResponse)
def update_profile(
    data: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = (
        db.query(Profile)
        .filter(Profile.user_id == current_user.id)
        .first()
    )

    if not profile:
        profile = ensure_profile(db, current_user.id)

    for field, value in data.model_dump().items():
        setattr(profile, field, value)

    db.commit()
    db.refresh(profile)

    return profile


@router.post("/avatar", response_model=ProfileResponse)
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    ext = ALLOWED_TYPES.get(file.content_type or "")
    if not ext:
        raise HTTPException(status_code=400, detail="Поддерживаются только JPEG, PNG и WEBP")

    data = await file.read()
    if len(data) > MAX_AVATAR_BYTES:
        raise HTTPException(status_code=400, detail="Файл слишком большой (макс. 5 МБ)")
    if not data:
        raise HTTPException(status_code=400, detail="Пустой файл")

    os.makedirs(AVATAR_DIR, exist_ok=True)

    profile = ensure_profile(db, current_user.id)
    _remove_avatar_file(profile.avatar_url)  # чистим прежний файл

    filename = f"{current_user.id}_{secrets.token_hex(6)}{ext}"
    with open(os.path.join(AVATAR_DIR, filename), "wb") as f:
        f.write(data)

    profile.avatar_url = f"/uploads/avatars/{filename}"
    db.commit()
    db.refresh(profile)
    return profile


@router.delete("/avatar", response_model=ProfileResponse)
def delete_avatar(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = ensure_profile(db, current_user.id)
    _remove_avatar_file(profile.avatar_url)
    profile.avatar_url = None
    db.commit()
    db.refresh(profile)
    return profile
