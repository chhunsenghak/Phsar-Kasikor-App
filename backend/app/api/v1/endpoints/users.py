from typing import Any, Dict
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.core import errors
from app.core.database import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserOut
from app.services import user_service

router = APIRouter()


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register_user(
    *,
    db: Session = Depends(get_db),
    user_in: UserCreate
) -> Any:
    """
    Register a new user. Checks if user with email already exists.
    """
    if user_in.email:
        user = user_service.get_user_by_email(db, email=user_in.email)
        if user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=errors.EMAIL_ALREADY_EXISTS,
            )
    
    # Enforce phone number uniqueness
    user_by_phone = user_service.get_user_by_phone(db, phone=user_in.phoneNumber)
    if user_by_phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=errors.PHONE_NUMBER_ALREADY_EXISTS,
        )
    return user_service.create_user(db, user_in=user_in)


@router.get("/", response_model=list[UserOut])
def read_users(
    db: Session = Depends(get_db),
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Get all active users.
    """
    return user_service.get_all_users(db, skip, limit)


@router.get("/me", response_model=UserOut)
def read_user_me(
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Get current active user details.
    """
    return current_user


@router.put("/me", response_model=UserOut)
def update_user_me(
    *,
    db: Session = Depends(get_db),
    user_in: Dict[str, Any],
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Update current user profile details (such as address).
    """
    allowed_keys = {"province", "district", "commune", "village", "street_address", "latitude", "longitude"}
    update_data = {k: v for k, v in user_in.items() if k in allowed_keys}
    return user_service.update_user(db, db_obj=current_user, obj_in=update_data)
