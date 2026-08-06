import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from app.models.base import Base

class VerificationCode(Base):
    """
    A short-lived, single-use code emailed to a user for either password
    reset or email verification. Only the SHA-256 hash is stored — like a
    password, the plaintext code should never be recoverable from the DB,
    since it briefly grants control of the account (reset) or the
    verified-email claim.
    """
    __tablename__ = "verification_codes"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    code_hash = Column(String, nullable=False)
    purpose = Column(String, nullable=False)  # password_reset, email_verification
    expires_at = Column(DateTime, nullable=False)
    used_at = Column(DateTime, nullable=True)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    user = relationship("User", backref="verification_codes")
