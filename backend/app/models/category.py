import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Numeric, Date, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from app.models.base import Base

class Category(Base):
    __tablename__ = "categories"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    description = Column(String, nullable=False)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Relationships
    products = relationship("Product", back_populates="category")
