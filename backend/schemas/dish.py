# schemas/dish.py
from pydantic import BaseModel, Field
from typing import List
from datetime import datetime


class Ingredient(BaseModel):
    name: str
    weight_g: float = Field(gt=0)
    carbs_per_100g: float = Field(ge=0)


class DishCreateRequest(BaseModel):
    title: str
    is_public: bool = False
    ingredients: List[Ingredient]


class DishUpdateRequest(BaseModel):
    title: str
    is_public: bool
    ingredients: List[Ingredient]


class DishResponse(BaseModel):
    id: int
    author_user_id: int
    title: str
    is_public: bool
    ingredients: list
    created_at: datetime
    likes_count: int = 0
    is_liked: bool = False
    is_favorited: bool = False

    class Config:
        from_attributes = True