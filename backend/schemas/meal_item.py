# schemas/meal_item.py
from pydantic import BaseModel
from typing import List
from datetime import datetime


class MealItemResponse(BaseModel):
    id: int
    type: str
    items: list
    total_carbs: float
    created_at: datetime

    class Config:
        from_attributes = True
