import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import Base

class FarmerCertificate(Base):
    __tablename__ = "farmer_certificates"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    certificate_type = Column(String, nullable=False)
    issuing_body = Column(String, nullable=True)
    document_url = Column(Text, nullable=False)
    status = Column(String, nullable=False, default="pending")
    admin_feedback = Column(Text, nullable=True)
    reviewed_at = Column(DateTime, nullable=True)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    user = relationship("User", backref="farmer_certificates")
