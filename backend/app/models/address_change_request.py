import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, DateTime, String, ForeignKey, Text, Float
from sqlalchemy.orm import relationship
from app.models.base import Base

class AddressChangeRequest(Base):
    __tablename__ = "address_change_requests"

    # Core Metadata
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    status = Column(String, nullable=False, default="PENDING")  # PENDING, APPROVED, REJECTED, SUPERSEDED, EXPIRED

    # Address Info
    province = Column(String, nullable=True)
    district = Column(String, nullable=True)
    commune = Column(String, nullable=True)
    village = Column(String, nullable=True)
    street_address = Column(String, nullable=True)

    # Geo-Coordinates
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)

    # Proof Document & Admin Review
    proof_document_url = Column(String, nullable=True)
    admin_feedback = Column(Text, nullable=True)

    # Timespan
    reviewed_at = Column(
        DateTime,
        default=None,
        nullable=True
    )
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Relationships
    user = relationship("User", backref="address_change_requests", foreign_keys=[user_id])



