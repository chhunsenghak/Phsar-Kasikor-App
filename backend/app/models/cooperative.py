import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from app.models.base import Base

class Cooperative(Base):
    __tablename__ = "cooperatives"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    leader_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    province = Column(String, nullable=True)
    description = Column(Text, nullable=True)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Relationships
    leader = relationship("User", backref="lead_cooperatives")
    members = relationship("CooperativeMember", back_populates="cooperative", cascade="all, delete-orphan")


class CooperativeMember(Base):
    __tablename__ = "cooperative_members"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    cooperative_id = Column(String(36), ForeignKey("cooperatives.id"), nullable=False, index=True)
    farmer_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    status = Column(String, nullable=False, default="active") # pending, active, rejected
    joined_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    __table_args__ = (
        UniqueConstraint("cooperative_id", "farmer_id", name="uq_coop_farmer_member"),
    )

    # Relationships
    cooperative = relationship("Cooperative", back_populates="members")
    farmer = relationship("User", backref="cooperative_memberships")
