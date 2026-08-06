import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Numeric, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from app.models.base import Base

class Dispute(Base):
    """
    A buyer or seller flagging a problem with a specific order — the
    backend's only path to ever actually set Order.payment_status to
    REFUNDED, which until now was a defined enum value nothing ever set.
    """
    __tablename__ = "disputes"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    order_id = Column(String(36), ForeignKey("orders.id"), nullable=False, index=True)
    raised_by = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    reason = Column(Text, nullable=False)
    status = Column(String, default="OPEN", nullable=False)  # OPEN, RESOLVED_REFUND, RESOLVED_REJECTED
    resolution_note = Column(Text, nullable=True)
    refund_amount = Column(Numeric(10, 2), nullable=True)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )
    resolved_at = Column(DateTime, nullable=True)

    order = relationship("Order", backref="disputes")
    raiser = relationship("User", foreign_keys=[raised_by], backref="disputes_raised")
