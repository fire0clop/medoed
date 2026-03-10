# routers/meal.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from db import get_db
from core.security import get_current_user
from models.user import User
from models.meal import Meal
from models.meal_item import MealItem
from schemas.meal import MealCreateRequest, MealResponse
from schemas.meal_item import MealItemResponse
from services.meal_builder import build_ingredients_from_dish

router = APIRouter(prefix="/meals", tags=["Meals"])


@router.post("", response_model=MealResponse)
def create_meal(
    data: MealCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    meal = Meal(
        user_id=current_user.id,
        eaten_at=data.eaten_at,
    )
    db.add(meal)
    db.flush()

    total_meal_carbs = 0.0

    for item in data.items:
        if item.type == "manual_total":
            meal_item = MealItem(
                meal_id=meal.id,
                type="manual_total",
                items=[
                    {
                        "description": item.description,
                        "carbs_total": item.total_carbs,
                    }
                ],
                total_carbs=item.total_carbs,
            )

        elif item.type == "ingredients":
            carbs = sum(i.carbs_total for i in item.ingredients)
            meal_item = MealItem(
                meal_id=meal.id,
                type="ingredients",
                items=[i.model_dump() for i in item.ingredients],
                total_carbs=carbs,
            )

        elif item.type == "dish":
            try:
                ingredients = build_ingredients_from_dish(
                    db=db,
                    dish_id=item.dish_id,
                    eaten_weight_g=item.eaten_weight_g,
                    user_id=current_user.id,
                )
            except PermissionError:
                raise HTTPException(403, "Access denied to this dish")
            except ValueError as e:
                raise HTTPException(400, str(e))
            carbs = sum(i["carbs_total"] for i in ingredients)
            meal_item = MealItem(
                meal_id=meal.id,
                type="ingredients",
                items=ingredients,
                total_carbs=carbs,
            )

        else:
            raise HTTPException(400, "Invalid meal item type")

        total_meal_carbs += meal_item.total_carbs
        db.add(meal_item)

    db.commit()
    return MealResponse(
        id=meal.id,
        eaten_at=meal.eaten_at,
        total_carbs=round(total_meal_carbs, 2),
    )


@router.get("", response_model=list[MealResponse])
def list_meals(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    meals = (
        db.query(Meal)
        .filter(Meal.user_id == current_user.id)
        .order_by(Meal.eaten_at.desc())
        .all()
    )

    result = []
    for meal in meals:
        total = (
            db.query(MealItem)
            .filter(MealItem.meal_id == meal.id)
            .with_entities(MealItem.total_carbs)
            .all()
        )
        result.append(
            MealResponse(
                id=meal.id,
                eaten_at=meal.eaten_at,
                total_carbs=round(sum(t[0] for t in total), 2),
            )
        )

    return result


@router.get("/{meal_id}/items", response_model=list[MealItemResponse])
def get_meal_items(
    meal_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    meal = (
        db.query(Meal)
        .filter(Meal.id == meal_id, Meal.user_id == current_user.id)
        .first()
    )
    if not meal:
        raise HTTPException(404, "Meal not found")

    return (
        db.query(MealItem)
        .filter(MealItem.meal_id == meal_id)
        .all()
    )
