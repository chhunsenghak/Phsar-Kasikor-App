from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api import deps
from app.core import errors
from app.core.database import get_db
from app.models.user import User
from app.models.product import Product
from app.schemas.review import ReviewCreate, ReviewOut, ReviewSummaryOut, ReviewableOrderOut
from app.services import review_service

router = APIRouter()

_ERROR_STATUS = {
    "ORDER_NOT_FOUND": 404,
    "NOT_AUTHORIZED": 403,
    "ORDER_NOT_DELIVERED": 400,
    "ORDER_ALREADY_REVIEWED": 400,
}

@router.post("/", response_model=ReviewOut, status_code=201)
def create_review(
    review_in: ReviewCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Rate a completed order. Only the buyer of a DELIVERED order can review
    it, and only once — reviews exist to signal real transaction history,
    not to be freely postable.
    """
    try:
        review = review_service.create_review(db, review_in=review_in, reviewer_id=current_user.id)
    except Exception as e:
        code = str(e)
        raise HTTPException(status_code=_ERROR_STATUS.get(code, 400), detail=code)

    out = ReviewOut.model_validate(review)
    out.reviewer_name = current_user.username
    if review.product_id:
        product = db.query(Product).filter(Product.id == review.product_id).first()
        out.product_name = product.product_name if product else None
    return out

@router.get("/seller/{seller_id}", response_model=List[ReviewOut])
def list_seller_reviews(
    seller_id: str,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    _current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Public review list for a farmer/seller — visible to any authenticated
    user, since it informs a buying decision before any transaction exists.
    """
    reviews = review_service.get_reviews_for_seller(db, seller_id=seller_id, skip=skip, limit=limit)
    results = []
    for r in reviews:
        out = ReviewOut.model_validate(r)
        reviewer = db.query(User).filter(User.id == r.reviewer_id).first()
        out.reviewer_name = reviewer.username if reviewer else "Buyer"
        if r.product_id:
            product = db.query(Product).filter(Product.id == r.product_id).first()
            out.product_name = product.product_name if product else None
        results.append(out)
    return results

@router.get("/seller/{seller_id}/summary", response_model=ReviewSummaryOut)
def get_seller_review_summary(
    seller_id: str,
    db: Session = Depends(get_db),
    _current_user: User = Depends(deps.get_current_user)
) -> Any:
    return review_service.get_review_summary(db, seller_id=seller_id)

@router.get("/reviewable-orders", response_model=List[ReviewableOrderOut])
def list_reviewable_orders(
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    The current buyer's delivered-but-not-yet-reviewed orders — what a
    "rate your recent purchases" prompt would list.
    """
    return review_service.get_reviewable_orders(db, buyer_id=current_user.id)
