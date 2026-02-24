# schemas/profile.py
from pydantic import BaseModel, Field


class ProfileResponse(BaseModel):
    target_glucose_mmol: float
    insulin_sensitivity_factor: float

    ic_ratio_breakfast: float
    ic_ratio_lunch: float
    ic_ratio_dinner: float

    avatar_url: str | None = None

    class Config:
        from_attributes = True


class ProfileUpdateRequest(BaseModel):
    target_glucose_mmol: float = Field(ge=0)
    insulin_sensitivity_factor: float = Field(ge=0)

    ic_ratio_breakfast: float = Field(ge=0)
    ic_ratio_lunch: float = Field(ge=0)
    ic_ratio_dinner: float = Field(ge=0)
