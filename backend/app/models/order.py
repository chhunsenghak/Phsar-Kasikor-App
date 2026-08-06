import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Numeric, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from app.models.base import Base

class Order(Base):
    __tablename__ = "orders"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    buyer_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    seller_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    total_amount = Column(Numeric(10, 2), nullable=False)
    currency = Column(String, default="USD", nullable=False) # USD or KHR — the products' currency, not a user choice
    payment_status = Column(String, default="PENDING", nullable=False) # PENDING, PAID, FAILED, REFUNDED
    order_status = Column(String, default="PLACED", nullable=False) # PLACED, CONFIRMED, SHIPPED, DELIVERED, CANCELLED
    payment_method = Column(String, default="KHQR", nullable=False) # KHQR, COD
    delivery_method = Column(String, default="DELIVERY", nullable=False) # DELIVERY, PICKUP
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Relationships
    buyer = relationship("User", foreign_keys=[buyer_id], backref="buyer_orders")
    seller = relationship("User", foreign_keys=[seller_id], backref="seller_orders")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")

    @property
    def buyer_name(self):
        return self.buyer.username if self.buyer else None

    @property
    def seller_name(self):
        return self.seller.username if self.seller else None
