# core/profile_defaults.py
from sqlalchemy.orm import Session

DEFAULT_PROFILE = dict(
    target_glucose_mmol=0,
    insulin_sensitivity_factor=0,
    ic_ratio_breakfast=0,
    ic_ratio_lunch=0,
    ic_ratio_dinner=0,
)


def ensure_profile(db: Session, user_id: int):
    from models.profile import Profile

    p = db.query(Profile).filter(Profile.user_id == user_id).first()
    if not p:
        p = Profile(user_id=user_id, **DEFAULT_PROFILE)
        db.add(p)
    return p
