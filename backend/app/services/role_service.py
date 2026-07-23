from typing import List, Optional
from sqlalchemy.orm import Session

from app.models.role import Role
from app.models.user_role import UserRole
from app.schemas.role import RoleCreate, RoleUpdate

def get_role_by_id(db: Session, role_id: int) -> Optional[Role]:
    """
    Retrieve a role by its integer ID.
    """
    return db.query(Role).filter(Role.id == role_id).first()

def get_role_by_name(db: Session, name: str) -> Optional[Role]:
    """
    Retrieve a role by its unique name (case-insensitive check, matching standard upper-case).
    """
    return db.query(Role).filter(Role.name == name.upper().strip()).first()

def get_all_roles(db: Session, skip: int = 0, limit: int = 100) -> List[Role]:
    """
    Retrieve a list of all defined roles.
    """
    return db.query(Role).offset(skip).limit(limit).all()

def create_role(db: Session, name: str, description: Optional[str] = None) -> Role:
    """
    Create a new role definition.
    """
    db_role = Role(
        name=name.upper().strip(),
        description=description
    )
    db.add(db_role)
    db.commit()
    db.refresh(db_role)
    return db_role

def update_role(db: Session, db_role: Role, role_update: RoleUpdate) -> Role:
    """
    Update an existing role's name or description.
    """
    if role_update.name is not None:
        db_role.name = role_update.name.upper().strip()
    if role_update.description is not None:
        db_role.description = role_update.description
    db.commit()
    db.refresh(db_role)
    return db_role

def delete_role(db: Session, db_role: Role) -> None:
    """
    Delete a role definition. Note: Cascading foreign keys will handle mapping removals.
    """
    db.delete(db_role)
    db.commit()

def assign_role_to_user(db: Session, user_id: str, role_id: int) -> UserRole:
    """
    Map a role to a user. Checks first to avoid duplicate unique constraint errors.
    """
    existing = db.query(UserRole).filter(
        UserRole.user_id == user_id,
        UserRole.role_id == role_id
    ).first()
    if existing:
        return existing

    association = UserRole(user_id=user_id, role_id=role_id)
    db.add(association)
    db.commit()
    db.refresh(association)
    return association

def remove_role_from_user(db: Session, user_id: str, role_id: int) -> None:
    """
    Remove a role mapping from a user.
    """
    association = db.query(UserRole).filter(
        UserRole.user_id == user_id,
        UserRole.role_id == role_id
    ).first()
    if association:
        db.delete(association)
        db.commit()
