from typing import Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.models.user import User
from app.schemas.category import CategoryCreate, CategoryOut, CategoryUpdate
from app.schemas.base import SuccessResponse
from app.core import errors, success
from app.services import category_service

router = APIRouter()

@router.get("/", response_model=List[CategoryOut])
def read_categories(
    db: Session = Depends(deps.get_db),
    skip: int = 0,  
    limit: int = 100,
) -> Any:
    """
    Retrieve all categories.
    """
    return category_service.get_categories(db, skip=skip, limit=limit)

@router.post("/", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
def create_category(
    category_in: CategoryCreate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Create a new category listing.
    """
    return category_service.create_category(db, category_in=category_in)

@router.get("/{category_id}", response_model=CategoryOut)
def read_category(
    category_id: str,
    db: Session = Depends(deps.get_db)
) -> Any:
    """
    Retrieve category details.
    """
    db_category = category_service.get_category(db, category_id=category_id)
    if not db_category:
        raise HTTPException(status_code=404, detail=errors.CATEGORY_NOT_FOUND)
    return db_category

@router.put("/{category_id}", response_model=CategoryOut)
def update_category(
    category_id: str,
    category_update: CategoryUpdate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Update a category listing. Only the owner can modify.
    """
    db_category = category_service.get_category(db, category_id=category_id)
    if not db_category:
        raise HTTPException(status_code=404, detail=errors.CATEGORY_NOT_FOUND)
    return category_service.update_category(db, db_category=db_category, category_update=category_update)

@router.delete("/{category_id}", response_model=SuccessResponse)
def delete_category(
    category_id: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Delete a category listing. Only authenticated users can delete.
    """
    db_category = category_service.get_category(db, category_id=category_id)
    if not db_category:
        raise HTTPException(status_code=404, detail=errors.CATEGORY_NOT_FOUND)
    category_service.delete_category(db, category_id=category_id)

    return success.make_success_response(success.CATEGORY_DELETED)
