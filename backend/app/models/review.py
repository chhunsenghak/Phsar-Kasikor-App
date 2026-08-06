import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Integer, Text, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship

from app.models.base import Base

class Review(Base):
    """
    A buyer's rating of a farmer, tied to one specific delivered order —
    only a real completed transaction earns the right to review, and only
    once per order, so this can't be spammed or faked.
    """
    __tablename__ = "reviews"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    order_id = Column(String(36), ForeignKey("orders.id"), nullable=False)
    reviewer_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    reviewee_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    product_id = Column(String(36), ForeignKey("products.id"), nullable=True)
    rating = Column(Integer, nullable=False)  # 1-5
    comment = Column(Text, nullable=True)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    reviewer = relationship("User", foreign_keys=[reviewer_id], backref="reviews_written")
    reviewee = relationship("User", foreign_keys=[reviewee_id], backref="reviews_received")
    order = relationship("Order", backref="review")
    product = relationship("Product")

    __table_args__ = (
        UniqueConstraint("order_id", name="uq_review_order"),
    )
