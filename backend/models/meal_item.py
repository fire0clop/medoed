# models/meal_item.py
from datetime import datetime
from sqlalchemy import Column, Integer, Float, String, JSON, DateTime, ForeignKey
from models.base import Base


class MealItem(Base):
    __tablename__ = "meal_items"

    id = Column(Integer, primary_key=True)
    meal_id = Column(Integer, ForeignKey("meals.id", ondelete="CASCADE"), nullable=False)

    type = Column(String, nullable=False)
    # manual_total | ingredients

    items = Column(JSON, nullable=False)
    total_carbs = Column(Float, nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow)
