# core/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # ===== APP =====
    APP_TITLE: str = "DiabetAI API"
    ENV: str = "dev"
    ROOT_PATH: str = ""

    # ===== DATABASE =====
    DATABASE_URL: str

    # ===== JWT =====
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # ===== EMAIL =====
    SMTP_HOST: str
    SMTP_PORT: int
    SMTP_USER: str
    SMTP_PASS: str
    FROM_EMAIL: str

    # ===== GOOGLE =====
    GOOGLE_IOS_CLIENT_ID: str
    GOOGLE_WEB_CLIENT_ID: str
    GOOGLE_WEB_CLIENT_SECRET: str
    GOOGLE_ALLOWED_AUDS: str

    # ===== APPLE =====
    APPLE_TEAM_ID: str
    APPLE_KEY_ID: str
    APPLE_BUNDLE_ID: str
    APPLE_PRIVATE_KEY_PATH: str

    class Config:
        env_file = ".env"
        extra = "forbid"

settings = Settings()
