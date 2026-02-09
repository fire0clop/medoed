# models/meal.py
from datetime import datetime
from sqlalchemy import Column, Integer, DateTime, ForeignKey
from models.base import Base


class Meal(Base):
    __tablename__ = "meals"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    eaten_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
