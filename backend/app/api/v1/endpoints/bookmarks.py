from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.core.database import get_db
from app.models.user import User
from app.models.product import Product
from app.models.saved_crop import SavedCrop
from app.schemas.saved_crop import SavedCropOut

router = APIRouter()

@router.get("/", response_model=List[SavedCropOut])
def get_bookmarks(
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Retrieve all products saved/bookmarked by current user.
    """
    saved = db.query(SavedCrop).filter(SavedCrop.user_id == current_user.id).order_by(SavedCrop.created_at.desc()).all()
    results = []
    for s in saved:
        s_out = SavedCropOut.model_validate(s)
        results.append(s_out)
    return results

@router.post("/{product_id}", response_model=SavedCropOut, status_code=status.HTTP_201_CREATED)
def add_bookmark(
    product_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Save/bookmark a product listing.
    """
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    existing = db.query(SavedCrop).filter(
        SavedCrop.user_id == current_user.id,
        SavedCrop.product_id == product_id
    ).first()
    if existing:
        return SavedCropOut.model_validate(existing)

    saved = SavedCrop(user_id=current_user.id, product_id=product_id)
    db.add(saved)
    db.commit()
    db.refresh(saved)
    return SavedCropOut.model_validate(saved)

@router.delete("/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_bookmark(
    product_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> None:
    """
    Remove a saved/bookmarked crop.
    """
    saved = db.query(SavedCrop).filter(
        SavedCrop.user_id == current_user.id,
        SavedCrop.product_id == product_id
    ).first()
    if saved:
        db.delete(saved)
        db.commit()
    return None
