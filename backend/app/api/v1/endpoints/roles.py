from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.core import errors
from app.core.database import get_db
from app.schemas.role import RoleCreate, RoleUpdate, RoleOut, RoleAssignment
from app.services import role_service, user_service

router = APIRouter()

@router.post("/", response_model=RoleOut, status_code=status.HTTP_201_CREATED)
def create_role(
    *,
    db: Session = Depends(get_db),
    role_in: RoleCreate
) -> Any:
    """
    Create a new role in the system.
    """
    db_role = role_service.get_role_by_name(db, name=role_in.name)
    if db_role:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Role with this name already exists",
        )
    return role_service.create_role(db, name=role_in.name, description=role_in.description)

@router.get("/", response_model=List[RoleOut])
def read_roles(
    db: Session = Depends(get_db),
    skip: int = 0,
    limit: int = 100
) -> Any:
    """
    Retrieve all roles.
    """
    return role_service.get_all_roles(db, skip=skip, limit=limit)

@router.get("/{role_id}", response_model=RoleOut)
def read_role(
    role_id: int,
    db: Session = Depends(get_db)
) -> Any:
    """
    Get details of a specific role.
    """
    db_role = role_service.get_role_by_id(db, role_id=role_id)
    if not db_role:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Role not found",
        )
    return db_role

@router.put("/{role_id}", response_model=RoleOut)
def update_role(
    *,
    db: Session = Depends(get_db),
    role_id: int,
    role_in: RoleUpdate
) -> Any:
    """
    Update a role's attributes.
    """
    db_role = role_service.get_role_by_id(db, role_id=role_id)
    if not db_role:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Role not found",
        )
    if role_in.name:
        existing_role = role_service.get_role_by_name(db, name=role_in.name)
        if existing_role and existing_role.id != role_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Role with this name already exists",
            )
    return role_service.update_role(db, db_role=db_role, role_update=role_in)

@router.delete("/{role_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_role(
    role_id: int,
    db: Session = Depends(get_db)
) -> None:
    """
    Delete a role definition.
    """
    db_role = role_service.get_role_by_id(db, role_id=role_id)
    if not db_role:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Role not found",
        )
    role_service.delete_role(db, db_role=db_role)

@router.post("/assign", status_code=status.HTTP_204_NO_CONTENT)
def assign_user_role(
    *,
    db: Session = Depends(get_db),
    payload: RoleAssignment
) -> None:
    """
    Assign a role to a user.
    """
    db_user = user_service.get_user_by_id(db, user_id=payload.user_id)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    db_role = role_service.get_role_by_id(db, role_id=payload.role_id)
    if not db_role:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Role not found",
        )
    role_service.assign_role_to_user(db, user_id=payload.user_id, role_id=payload.role_id)

@router.post("/remove", status_code=status.HTTP_204_NO_CONTENT)
def remove_user_role(
    *,
    db: Session = Depends(get_db),
    payload: RoleAssignment
) -> None:
    """
    Remove a role from a user.
    """
    db_user = user_service.get_user_by_id(db, user_id=payload.user_id)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    db_role = role_service.get_role_by_id(db, role_id=payload.role_id)
    if not db_role:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Role not found",
        )
    role_service.remove_role_from_user(db, user_id=payload.user_id, role_id=payload.role_id)
