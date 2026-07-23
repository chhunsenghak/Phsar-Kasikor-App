import re
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core import errors
from app.models.user import UserRole


class UserBase(BaseModel):
    email: Optional[str] = Field(None, description="The user's email address")
    username: Optional[str] = Field(None, min_length=3, max_length=50, description="The user's username")
    phoneNumber: str = Field(..., description="The user's unique phone number")
    role_id: int = Field(..., description="The integer ID of the user's role (e.g. 1, 2, 3...)")
    province: Optional[str] = Field(None, description="The province/city name (optional)")
    district: Optional[str] = Field(None, description="The district/khan name (optional)")
    commune: Optional[str] = Field(None, description="The commune/sangkat name (optional)")
    village: Optional[str] = Field(None, description="The village name (optional)")
    street_address: Optional[str] = Field(None, description="The street address/house number (optional)")

    @field_validator("email")
    @classmethod
    def validate_email_format(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        # Simple email regex validation
        email_regex = r"^[\w\.-]+@[\w\.-]+\.\w+$"
        if not re.match(email_regex, value):
            raise ValueError(errors.INVALID_EMAIL_FORMAT)
        return value.lower().strip()


class UserCreate(UserBase):
    password: str = Field(..., description="The user's password (min 8 characters)")

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        if len(value) < 8:
            raise ValueError(errors.PASSWORD_MIN_8_CHARACTERS)
        return value


class UserUpdate(BaseModel):
    email: Optional[str] = None
    username: Optional[str] = None
    password: Optional[str] = None
    phoneNumber: Optional[str] = None
    role_id: Optional[int] = None
    province: Optional[str] = None
    district: Optional[str] = None
    commune: Optional[str] = None
    village: Optional[str] = None
    street_address: Optional[str] = None

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: Optional[str]) -> Optional[str]:
        if value is not None and len(value) < 8:
            raise ValueError(errors.PASSWORD_MIN_8_CHARACTERS)
        return value


class UserOut(UserBase):
    id: str
    is_active: bool
    is_verified: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class Token(BaseModel):
    access_token: str
    token_type: str


class TokenPayload(BaseModel):
    sub: Optional[str] = None
