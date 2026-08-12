import uuid
from sqlalchemy import Column, String, Numeric, Date, DateTime, Text, ForeignKey
from sqlalchemy.orm import relationship

from app.models.base import Base

class Contract(Base):
    __tablename__ = "contracts"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    seller_id = Column(String(36), ForeignKey("users.id"), nullable=False) # Producer/Cooperative
    buyer_id = Column(String(36), ForeignKey("users.id"), nullable=False) # Wholesale Buyer
    terms_description = Column(Text, nullable=True)
    start_date = Column(DateTime(timezone=True), nullable=False)
    end_date = Column(DateTime(timezone=True), nullable=False)
    contract_status = Column(String, default="DRAFT", nullable=False) # DRAFT, PENDING_DEPOSIT, ACTIVE, PENDING_FINAL_PAYMENT, IN_FULFILLMENT, COMPLETED, TERMINATED

    # Booking deposit — the buyer's trust signal to the seller before the
    # contract becomes binding. Set by the seller on acceptance (see
    # contract_service.update_contract); paid via the same KHQR
    # infrastructure as orders. deposit_status is PENDING/PAID; ACTIVE is
    # only ever reached once this actually settles.
    deposit_percentage = Column(Numeric(5, 2), nullable=True)
    deposit_amount = Column(Numeric(10, 2), nullable=True)
    deposit_status = Column(String, nullable=True)  # PENDING, PAID
    deposit_currency = Column(String, nullable=True)
    deposit_khqr_md5 = Column(String, nullable=True, index=True)
    deposit_khqr_qr_string = Column(String, nullable=True)

    # Final balance settlement — set by the seller once when actually ready
    # to deliver (see contract_service.update_contract's PENDING_FINAL_PAYMENT
    # branch), not upfront at acceptance, since the real delivery cost
    # (e.g. hiring local transport) usually isn't known until then.
    # delivery_fee is a plain seller-entered amount (never auto-calculated
    # the way order_service computes one from distance/weight — a wholesale
    # contract's logistics don't fit that formula). final_amount is the
    # remaining contract balance (agreed total - deposit already paid) plus
    # delivery_fee; COMPLETED is only ever reached once this settles.
    delivery_method = Column(String, nullable=True)  # DELIVERY, PICKUP
    delivery_fee = Column(Numeric(10, 2), nullable=True)
    final_amount = Column(Numeric(10, 2), nullable=True)
    final_payment_status = Column(String, nullable=True)  # PENDING, PAID
    final_khqr_md5 = Column(String, nullable=True, index=True)
    final_khqr_qr_string = Column(String, nullable=True)

    # Once the final payment settles, fulfillment is handed off to a real
    # Order (see order_service.create_order_from_contract) so delivery
    # tracking reuses the order system entirely instead of a second
    # parallel implementation — no reverse column on Order; it's found by
    # querying fulfillment_order_id back from this side. COMPLETED is only
    # ever reached once that order is DELIVERED (see
    # contract_service.complete_contract_from_fulfillment).
    fulfillment_order_id = Column(String(36), nullable=True, index=True)

    # Relationships
    seller = relationship("User", foreign_keys=[seller_id], backref="contracts_as_seller")
    buyer = relationship("User", foreign_keys=[buyer_id], backref="contracts_as_buyer")
    items = relationship("ContractItem", back_populates="contract", cascade="all, delete-orphan")

    @property
    def buyer_name(self):
        return self.buyer.username if self.buyer else None

    @property
    def seller_name(self):
        return self.seller.username if self.seller else None


class ContractItem(Base):
    __tablename__ = "contract_items"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    contract_id = Column(String(36), ForeignKey("contracts.id"), nullable=False)
    product_id = Column(String(36), ForeignKey("products.id"), nullable=False)
    agreed_price = Column(Numeric(10, 2), nullable=False)
    agreed_quantity = Column(Numeric(10, 2), nullable=False)
    unit_type = Column(String, nullable=False)

    # Relationships
    contract = relationship("Contract", back_populates="items")
    product = relationship("Product")
