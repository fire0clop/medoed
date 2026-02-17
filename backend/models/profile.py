# models/profile.py
from sqlalchemy import Column, Integer, Float, ForeignKey, String
from models.base import Base

class Profile(Base):
    __tablename__ = "profiles"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    target_glucose_mmol = Column(Float, nullable=False)
    insulin_sensitivity_factor = Column(Float, nullable=False)

    ic_ratio_breakfast = Column(Float, nullable=False)
    ic_ratio_lunch = Column(Float, nullable=False)
    ic_ratio_dinner = Column(Float, nullable=False)

    # Относительный URL загруженного аватара (например /uploads/avatars/3_ab12.jpg).
    # NULL → на клиенте показывается дефолтный силуэт.
    avatar_url = Column(String, nullable=True)
