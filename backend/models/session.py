# models/session.py
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from datetime import datetime
from models.base import Base

class Session(Base):
    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))

    refresh_token = Column(String, unique=True, index=True)
    user_agent = Column(String)
    ip_address = Column(String)

    expires_at = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow)
