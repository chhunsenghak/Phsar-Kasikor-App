from typing import Optional
from sqlalchemy.orm import Session

from app.core.security import get_password_hash, verify_password
from app.models.user import User
from app.schemas.user import UserCreate


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """
    Retrieve a user from the database by email address.
    """
    return db.query(User).filter(User.email == email).first()


def get_user_by_id(db: Session, user_id: str) -> Optional[User]:
    """
    Retrieve a user from the database by their ID.
    """
    return db.query(User).filter(User.id == user_id).first()


def create_user(db: Session, user_in: UserCreate) -> User:
    """
    Create a new user in the database with a hashed password.
    """
    db_obj = User(
        email=user_in.email,
        password=get_password_hash(user_in.password),
        username=user_in.username,
        phoneNumber=user_in.phoneNumber,
        role=user_in.role,
        address=user_in.address,
    )
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj


def authenticate_user(db: Session, email: str, password: str) -> Optional[User]:
    """
    Authenticate a user by checking their email and verifying their password.
    """
    user = get_user_by_email(db, email)
    if not user:
        return None
    if not verify_password(password, user.password):
        return None
    return user
