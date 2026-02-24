# schemas/meal.py
from pydantic import BaseModel, Field
from typing import List, Literal
from datetime import datetime


# ===== INGREDIENT SNAPSHOT =====

class MealIngredient(BaseModel):
    name: str
    weight_g: float = Field(gt=0)
    carbs_per_100g: float = Field(ge=0)
    carbs_total: float = Field(ge=0)


# ===== REQUEST ITEMS =====

class MealItemManual(BaseModel):
    type: Literal["manual_total"]
    description: str
    total_carbs: float = Field(ge=0)


class MealItemIngredients(BaseModel):
    type: Literal["ingredients"]
    ingredients: List[MealIngredient]


class MealItemFromDish(BaseModel):
    type: Literal["dish"]
    dish_id: int
    eaten_weight_g: float = Field(gt=0)


MealItemCreate = MealItemManual | MealItemIngredients | MealItemFromDish


# ===== MEAL =====

class MealCreateRequest(BaseModel):
    eaten_at: datetime
    items: List[MealItemCreate]


class MealResponse(BaseModel):
    id: int
    eaten_at: datetime
    total_carbs: float

    class Config:
        from_attributes = True
