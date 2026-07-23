import enum
import uuid
from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Integer, String
from sqlalchemy.orm import relationship

from app.models.base import Base

class UserRole(str, enum.Enum):
    FARMER = "FARMER"
    BUYER = "BUYER"
    MERCHANT = "MERCHANT"
    ADMIN = "ADMIN"


class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String, unique=True, index=True, nullable=True)
    password = Column(String, nullable=False)
    username = Column(String, nullable=True)
    phoneNumber= Column(String, nullable=False, unique=True, index=True)
    province = Column(String, nullable=True)
    district = Column(String, nullable=True)
    commune = Column(String, nullable=True)
    village = Column(String, nullable=True)
    street_address = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    is_deleted = Column(Boolean, default=False)
    deleted_at = Column(DateTime, nullable=True)
    deleted_by = Column(String(36), nullable=True)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Relationship to Role model via UserRole junction table
    roles = relationship("Role", secondary="user_roles", back_populates="users")

    @property
    def role_id(self) -> int:
        if self.roles:
            return self.roles[0].id
        return 6  # Fallback/default role ID

    @role_id.setter
    def role_id(self, value):
        # Setter is defined to prevent exceptions during keyword instantiation
        pass
