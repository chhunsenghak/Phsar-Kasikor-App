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


def get_user_by_phone(db: Session, phone: str) -> Optional[User]:
    """
    Retrieve a user from the database by phone number.
    """
    return db.query(User).filter(User.phoneNumber == phone).first()


def create_user(db: Session, user_in: UserCreate) -> User:
    """
    Create a new user in the database with a hashed password and associate them with a Role.
    """
    db_obj = User(
        email=user_in.email,
        password=get_password_hash(user_in.password),
        username=user_in.username,
        phoneNumber=user_in.phoneNumber,
        province=user_in.province,
        district=user_in.district,
        commune=user_in.commune,
        village=user_in.village,
        street_address=user_in.street_address,
    )
    db.add(db_obj)
    db.flush()  # Flush to generate db_obj.id for the junction table

    # Resolve role by ID and associate
    from app.services import role_service
    from fastapi import HTTPException, status
    db_role = role_service.get_role_by_id(db, role_id=user_in.role_id)
    if not db_role:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Role with ID {user_in.role_id} does not exist"
        )
    
    role_service.assign_role_to_user(db, user_id=db_obj.id, role_id=db_role.id)

    db.commit()
    db.refresh(db_obj)
    return db_obj


def authenticate_user(db: Session, email: str, password: str) -> Optional[User]:
    """
    Authenticate a user by checking their email or phone number, and verifying their password.
    Note: the parameter 'email' contains the user-provided login identifier (which can be email or phone).
    """
    user = None
    if email:
        user = get_user_by_email(db, email)
        if not user:
            user = get_user_by_phone(db, email)
            
    if not user:
        return None
    if not verify_password(password, user.password):
        return None
    return user
