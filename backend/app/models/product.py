import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Numeric, Date, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from app.models.base import Base

class Product(Base):
    __tablename__ = "products"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    seller_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    product_name = Column(String, nullable=False)
    category_id = Column(String(36), ForeignKey("categories.id"), nullable=False)
    price_per_unit = Column(Numeric(10, 2), nullable=False)
    unit_type = Column(String, nullable=False) # e.g. Kilogram, Sack, Ton
    currency = Column(String, default="USD", nullable=False) # USD or KHR
    quantity_available = Column(Numeric(10, 2), nullable=False)
    # How much one unit_type unit weighs, e.g. 50.0 for a SACK of rice.
    # Nullable — a farmer who hasn't set this yet falls back to a rough
    # per-unit-type default when pricing delivery (see order_service).
    weight_kg_per_unit = Column(Numeric(10, 2), nullable=True)
    harvest_date = Column(Date, nullable=True)
    quality_certification_metadata = Column(Text, nullable=True)
    status = Column(String, default="active", nullable=False) # active, inactive, deleted
    image_url = Column(String, nullable=True)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        onupdate=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    seller = relationship("User", backref="products")
    category = relationship("Category", back_populates="products")
