# models/dish.py
from datetime import datetime
from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    ForeignKey,
    JSON,
)
from models.base import Base


class Dish(Base):
    __tablename__ = "dishes"

    id = Column(Integer, primary_key=True)
    author_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))

    title = Column(String, nullable=False)
    is_public = Column(Boolean, default=False)

    ingredients = Column(JSON, nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow)