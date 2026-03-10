# routers/dishes.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_, func

from db import get_db
from core.security import get_current_user
from models.user import User
from models.dish import Dish
from models.dish_like import DishLike
from models.dish_favorite import DishFavorite
from schemas.dish import DishCreateRequest, DishUpdateRequest, DishResponse

router = APIRouter(prefix="/dishes", tags=["Dishes"])


# =========================
# CRUD DISHES
# =========================

@router.post("", response_model=DishResponse)
def create_dish(
    data: DishCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    dish = Dish(
        author_user_id=current_user.id,
        title=data.title,
        is_public=data.is_public,
        ingredients=[i.model_dump() for i in data.ingredients],
    )
    db.add(dish)
    db.commit()
    db.refresh(dish)
    return dish


@router.get("", response_model=list[DishResponse])
def list_dishes(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # базовый список
    dishes = (
        db.query(Dish)
        .filter(
            or_(
                Dish.is_public.is_(True),
                Dish.author_user_id == current_user.id,
            )
        )
        .order_by(Dish.created_at.desc())
        .all()
    )

    result = []

    for dish in dishes:
        # лайки всего
        likes_count = (
            db.query(func.count(DishLike.id))
            .filter(DishLike.dish_id == dish.id)
            .scalar()
        )

        # лайк текущего пользователя
        is_liked = (
            db.query(DishLike)
            .filter(
                DishLike.dish_id == dish.id,
                DishLike.user_id == current_user.id,
            )
            .first()
            is not None
        )

        # избранное текущего пользователя
        is_favorited = (
            db.query(DishFavorite)
            .filter(
                DishFavorite.dish_id == dish.id,
                DishFavorite.user_id == current_user.id,
            )
            .first()
            is not None
        )

        result.append(
            DishResponse(
                id=dish.id,
                author_user_id=dish.author_user_id,
                title=dish.title,
                is_public=dish.is_public,
                ingredients=dish.ingredients,
                created_at=dish.created_at,
                likes_count=likes_count,
                is_liked=is_liked,
                is_favorited=is_favorited,
            )
        )

    return result


@router.get("/{dish_id}", response_model=DishResponse)
def get_dish(
    dish_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    dish = db.query(Dish).filter(Dish.id == dish_id).first()
    if not dish:
        raise HTTPException(404, "Dish not found")

    if not dish.is_public and dish.author_user_id != current_user.id:
        raise HTTPException(403, "Access denied")

    likes_count = (
        db.query(func.count(DishLike.id))
        .filter(DishLike.dish_id == dish.id)
        .scalar()
    )

    is_liked = (
        db.query(DishLike)
        .filter(
            DishLike.dish_id == dish.id,
            DishLike.user_id == current_user.id,
        )
        .first()
        is not None
    )

    is_favorited = (
        db.query(DishFavorite)
        .filter(
            DishFavorite.dish_id == dish.id,
            DishFavorite.user_id == current_user.id,
        )
        .first()
        is not None
    )

    return DishResponse(
        id=dish.id,
        author_user_id=dish.author_user_id,
        title=dish.title,
        is_public=dish.is_public,
        ingredients=dish.ingredients,
        created_at=dish.created_at,
        likes_count=likes_count,
        is_liked=is_liked,
        is_favorited=is_favorited,
    )


@router.put("/{dish_id}", response_model=DishResponse)
def update_dish(
    dish_id: int,
    data: DishUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    dish = db.query(Dish).filter(Dish.id == dish_id).first()
    if not dish:
        raise HTTPException(404, "Dish not found")

    if dish.author_user_id != current_user.id:
        raise HTTPException(403, "Not your dish")

    dish.title = data.title
    dish.is_public = data.is_public
    dish.ingredients = [i.model_dump() for i in data.ingredients]

    db.commit()
    db.refresh(dish)
    return dish


@router.delete("/{dish_id}")
def delete_dish(
    dish_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    dish = db.query(Dish).filter(Dish.id == dish_id).first()
    if not dish:
        raise HTTPException(404, "Dish not found")

    if dish.author_user_id != current_user.id:
        raise HTTPException(403, "Not your dish")

    db.delete(dish)
    db.commit()
    return {"ok": True}


# =========================
# LIKES
# =========================

@router.post("/{dish_id}/like")
def like_dish(
    dish_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    like = DishLike(dish_id=dish_id, user_id=current_user.id)
    db.add(like)
    try:
        db.commit()
    except Exception:
        db.rollback()
    return {"ok": True}


@router.delete("/{dish_id}/like")
def unlike_dish(
    dish_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.query(DishLike).filter(
        DishLike.dish_id == dish_id,
        DishLike.user_id == current_user.id,
    ).delete()
    db.commit()
    return {"ok": True}


# =========================
# FAVORITES
# =========================

@router.post("/{dish_id}/favorite")
def favorite_dish(
    dish_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    fav = DishFavorite(dish_id=dish_id, user_id=current_user.id)
    db.add(fav)
    try:
        db.commit()
    except Exception:
        db.rollback()
    return {"ok": True}


@router.delete("/{dish_id}/favorite")
def unfavorite_dish(
    dish_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.query(DishFavorite).filter(
        DishFavorite.dish_id == dish_id,
        DishFavorite.user_id == current_user.id,
    ).delete()
    db.commit()
    return {"ok": True}
