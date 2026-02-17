# schemas/auth.py
from pydantic import BaseModel, EmailStr, Field


# ===== EMAIL =====

class EmailSendCodeRequest(BaseModel):
    email: EmailStr


class EmailConfirmRegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=256)
    code: str


class EmailLoginRequest(BaseModel):
    email: EmailStr
    password: str


# ===== GOOGLE =====

class GoogleAuthRequest(BaseModel):
    id_token: str


# ===== APPLE =====

class AppleAuthRequest(BaseModel):
    identity_token: str


# ===== REFRESH / LOGOUT =====

class RefreshRequest(BaseModel):
    refresh_token: str
