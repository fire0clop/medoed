# models/dish_like.py
from sqlalchemy import Column, Integer, ForeignKey, UniqueConstraint
from models.base import Base


class DishLike(Base):
    __tablename__ = "dish_likes"

    id = Column(Integer, primary_key=True)
    dish_id = Column(Integer, ForeignKey("dishes.id", ondelete="CASCADE"))
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))

    __table_args__ = (
        UniqueConstraint("dish_id", "user_id", name="uq_dish_like"),
    )
