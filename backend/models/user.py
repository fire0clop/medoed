# models/user.py
from sqlalchemy import Column, Integer, String, Boolean
from sqlalchemy.orm import relationship
from models.base import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    email = Column(String, unique=True, index=True, nullable=True)
    hashed_password = Column(String, nullable=True)

    # Стабильный идентификатор Apple Sign In (поле sub в identity token)
    apple_sub = Column(String, unique=True, index=True, nullable=True)

    provider = Column(String, nullable=False)  # email / google / apple
    is_active = Column(Boolean, default=True)

    profile = relationship("Profile", uselist=False, cascade="all, delete")
    sessions = relationship("Session", cascade="all, delete")
