# services/meal_builder.py
from sqlalchemy.orm import Session

from models.dish import Dish


def build_ingredients_from_dish(
    db: Session,
    dish_id: int,
    eaten_weight_g: float,
    user_id: int,
) -> list[dict]:
    dish = db.query(Dish).filter(Dish.id == dish_id).first()
    if not dish:
        raise ValueError("Dish not found")

    if not dish.is_public and dish.author_user_id != user_id:
        raise PermissionError("Private dish")

    base_weight = sum(i["weight_g"] for i in dish.ingredients)
    if base_weight <= 0:
        raise ValueError("Invalid dish ingredients")

    coef = eaten_weight_g / base_weight

    ingredients = []

    for ing in dish.ingredients:
        weight = ing["weight_g"] * coef
        carbs_total = weight * ing["carbs_per_100g"] / 100

        ingredients.append(
            {
                "name": ing["name"],
                "weight_g": round(weight, 2),
                "carbs_per_100g": ing["carbs_per_100g"],
                "carbs_total": round(carbs_total, 2),
            }
        )

    return ingredients
