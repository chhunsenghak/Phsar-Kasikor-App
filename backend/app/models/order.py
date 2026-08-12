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
    delivery_fee = Column(Numeric(10, 2), default=0, nullable=False)

    # Buyer-chosen drop-off point, captured once at checkout — a snapshot,
    # not a live pointer to the buyer's profile address, since the profile
    # can change after the order is placed.
    delivery_address_text = Column(String, nullable=True)
    delivery_lat = Column(Numeric(10, 8), nullable=True)
    delivery_lng = Column(Numeric(11, 8), nullable=True)

    # Snapshot of what delivery_fee was actually computed from — kept so a
    # later profile-address change by the seller can't retroactively change
    # what an old order's fee "should" have been.
    delivery_distance_km = Column(Numeric(8, 2), nullable=True)
    delivery_weight_kg = Column(Numeric(10, 2), nullable=True)

    # Links a generated KHQR to the order(s) it covers, so a payment status
    # check/confirm on that md5 knows which orders to settle.
    khqr_md5 = Column(String, nullable=True, index=True)

    # The exact QR string the md5 above was hashed from. Bakong's dynamic
    # KHQR embeds a fresh timestamp on every build, so re-running QR
    # generation for the same order — e.g. a hot reload or re-opening the
    # checkout screen — produces a different string and thus a different
    # md5, silently orphaning a QR the buyer may already have paid. Storing
    # it lets generation reuse the original QR (re-rendering the image is
    # pure/local and needs no new Bakong call) instead of minting a new one.
    khqr_qr_string = Column(String, nullable=True)

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
