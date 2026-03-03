# schemas/user.py
from pydantic import BaseModel, EmailStr


class UserBase(BaseModel):
    id: int
    email: EmailStr | None
    provider: str

    class Config:
        from_attributes = True
