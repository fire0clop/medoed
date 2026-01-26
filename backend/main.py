# main.py
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from core.config import settings
from db import engine
from models.base import Base

from routes import auth, profile, dishes, meals

Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.APP_TITLE)
app.router.redirect_slashes = False

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Статика загруженных файлов (аватары). Каталог создаётся при старте.
UPLOADS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
os.makedirs(os.path.join(UPLOADS_DIR, "avatars"), exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")

app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(dishes.router)
app.include_router(meals.router)

@app.get("/")
def root():
    return {"status": "ok"}
