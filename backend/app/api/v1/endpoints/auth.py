from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.core import errors, security
from app.core.database import get_db
from app.schemas.user import Token
from app.services import user_service

router = APIRouter()


@router.post("/login", response_model=Token)
def login(
    db: Session = Depends(get_db),
    form_data: OAuth2PasswordRequestForm = Depends()
) -> Any:
    """
    OAuth2 compatible token login. Returns an access token for subsequent API requests.
    Note: username in form_data corresponds to the user's email.
    """
    user = user_service.authenticate_user(
        db, email=form_data.username, password=form_data.password
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=errors.INCORRECT_CREDENTIALS,
        )
    elif not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=errors.INACTIVE_USER,
        )
    
    return {
        "access_token": security.create_access_token(user.id),
        "token_type": "bearer",
    }
