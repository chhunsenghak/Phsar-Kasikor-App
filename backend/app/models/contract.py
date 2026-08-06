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
    contract_status = Column(String, default="DRAFT", nullable=False) # DRAFT, ACTIVE, COMPLETED, TERMINATED

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
