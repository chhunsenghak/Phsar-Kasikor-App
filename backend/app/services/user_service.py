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
    import uuid
    user_id = str(uuid.uuid4())
    db_obj = User(
        id=user_id,
        email=user_in.email,
        password=get_password_hash(user_in.password),
        username=user_in.username,
        phoneNumber=user_in.phoneNumber,
    )
    db.add(db_obj)
    db.flush()  # Flush to generate IDs for relationships

    # Seed the initial address as an approved AddressChangeRequest record
    from app.models.address_change_request import AddressChangeRequest
    initial_address = AddressChangeRequest(
        user_id=user_id,
        status="APPROVED",
        province=user_in.province,
        district=user_in.district,
        commune=user_in.commune,
        village=user_in.village,
        street_address=user_in.street_address,
        latitude=user_in.latitude,
        longitude=user_in.longitude
    )
    db.add(initial_address)
    db.flush()

    db_obj.address_id = initial_address.id
    db.flush()

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


def get_all_users(db: Session, skip: int = 0, limit: int = 100) -> list[User]:
    """
    Retrieve all active users from the database.
    """
    return db.query(User).offset(skip).limit(limit).all()


def update_user(db: Session, db_obj: User, obj_in: dict) -> User:
    """
    Update user profile details in the database.
    """
    # Check if we are updating any address fields
    address_keys = {"province", "district", "commune", "village", "street_address", "latitude", "longitude"}
    has_address_update = any(k in obj_in for k in address_keys)
    
    if has_address_update:
        from app.models.address_change_request import AddressChangeRequest
        new_address = AddressChangeRequest(
            user_id=db_obj.id,
            status="APPROVED",
            province=obj_in.get("province", db_obj.province),
            district=obj_in.get("district", db_obj.district),
            commune=obj_in.get("commune", db_obj.commune),
            village=obj_in.get("village", db_obj.village),
            street_address=obj_in.get("street_address", db_obj.street_address),
            latitude=obj_in.get("latitude", db_obj.latitude),
            longitude=obj_in.get("longitude", db_obj.longitude)
        )
        db.add(new_address)
        db.flush()
        db_obj.address_id = new_address.id
        db.flush()

    for key, val in obj_in.items():
        if key not in address_keys and hasattr(db_obj, key):
            setattr(db_obj, key, val)
            
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj
