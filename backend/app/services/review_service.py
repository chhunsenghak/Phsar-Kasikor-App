from typing import List, Optional
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.review import Review
from app.models.order import Order
from app.models.order_item import OrderItem
from app.models.user import User
from app.models.product import Product
from app.schemas.review import ReviewCreate


def create_review(db: Session, review_in: ReviewCreate, reviewer_id: str) -> Review:
    order = db.query(Order).filter(Order.id == review_in.order_id).first()
    if not order:
        raise Exception("ORDER_NOT_FOUND")
    if order.buyer_id != reviewer_id:
        raise Exception("NOT_AUTHORIZED")
    if order.order_status != "DELIVERED":
        raise Exception("ORDER_NOT_DELIVERED")

    existing = db.query(Review).filter(Review.order_id == order.id).first()
    if existing:
        raise Exception("ORDER_ALREADY_REVIEWED")

    first_item = db.query(OrderItem).filter(OrderItem.order_id == order.id).first()

    review = Review(
        order_id=order.id,
        reviewer_id=reviewer_id,
        reviewee_id=order.seller_id,
        product_id=first_item.product_id if first_item else None,
        rating=review_in.rating,
        comment=review_in.comment,
    )
    db.add(review)
    db.commit()
    db.refresh(review)
    return review


def get_reviews_for_seller(db: Session, seller_id: str, skip: int = 0, limit: int = 100) -> List[Review]:
    return (
        db.query(Review)
        .filter(Review.reviewee_id == seller_id)
        .order_by(Review.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_review_summary(db: Session, seller_id: str) -> dict:
    result = (
        db.query(func.avg(Review.rating), func.count(Review.id))
        .filter(Review.reviewee_id == seller_id)
        .first()
    )
    avg_rating, count = result if result else (None, 0)
    return {
        "average_rating": round(float(avg_rating), 1) if avg_rating is not None else 0.0,
        "review_count": count or 0,
    }


def get_reviewable_orders(db: Session, buyer_id: str) -> List[dict]:
    """
    Delivered orders belonging to this buyer that don't have a review yet —
    what a "rate your recent purchases" list would show.
    """
    reviewed_order_ids = {
        r.order_id for r in db.query(Review.order_id).filter(Review.reviewer_id == buyer_id).all()
    }
    orders = (
        db.query(Order)
        .filter(Order.buyer_id == buyer_id, Order.order_status == "DELIVERED")
        .order_by(Order.created_at.desc())
        .all()
    )

    results = []
    for order in orders:
        if order.id in reviewed_order_ids:
            continue
        seller = db.query(User).filter(User.id == order.seller_id).first()
        first_item = db.query(OrderItem).filter(OrderItem.order_id == order.id).first()
        product_name = None
        if first_item:
            product = db.query(Product).filter(Product.id == first_item.product_id).first()
            product_name = product.product_name if product else None
        results.append({
            "order_id": order.id,
            "seller_id": order.seller_id,
            "seller_name": seller.username if seller else None,
            "product_name": product_name,
            "delivered_at": None,
        })
    return results
