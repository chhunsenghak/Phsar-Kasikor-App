from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.core import errors
from app.core.config import settings
from app.core.database import get_db
from app.core.security import ALGORITHM
from app.models.user import User
from app.schemas.user import TokenPayload
from app.services import user_service

# Defines the token URL for OAuth2 password flow
reusable_oauth2 = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_STR}/auth/login"
)


def get_current_user(
    db: Session = Depends(get_db),
    token: str = Depends(reusable_oauth2)
) -> User:
    """
    Dependency that decodes the bearer JWT token, validates it, and fetches the
    corresponding active user from the database.
    """
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[ALGORITHM]
        )
        token_data = TokenPayload(**payload)
        if token_data.sub is None:
            raise JWTError()
    except (JWTError, ValidationError):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=errors.COULD_NOT_VALIDATE_CREDENTIALS,
        )
    
    # We query the user by the ID stored in 'sub' claim
    user = user_service.get_user_by_id(db, user_id=token_data.sub)
    if not user:
        raise HTTPException(status_code=404, detail=errors.USER_NOT_FOUND)
    if not user.is_active:
        raise HTTPException(status_code=400, detail=errors.INACTIVE_USER)
    return user
