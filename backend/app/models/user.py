import enum
import uuid
from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Integer, String, Numeric, ForeignKey
from sqlalchemy.orm import relationship
from typing import Optional
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
    profile_image_url = Column(String, nullable=True)
    address_id = Column(String(36), ForeignKey("address_change_requests.id", use_alter=True, name="fk_user_address"), nullable=True)

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

    # Relationships
    roles = relationship("Role", secondary="user_roles", back_populates="users")
    address = relationship("AddressChangeRequest", foreign_keys=[address_id], post_update=True)

    @property
    def role_id(self) -> int:
        if self.roles:
            return self.roles[0].id
        return 6  # Fallback/default role ID

    @role_id.setter
    def role_id(self, value):
        # Setter is defined to prevent exceptions during keyword instantiation
        pass

    # Dynamic location properties (backward compatible with Pydantic serialization)
    @property
    def province(self) -> Optional[str]:
        return self.address.province if self.address else None

    @property
    def district(self) -> Optional[str]:
        return self.address.district if self.address else None

    @property
    def commune(self) -> Optional[str]:
        return self.address.commune if self.address else None

    @property
    def village(self) -> Optional[str]:
        return self.address.village if self.address else None

    @property
    def street_address(self) -> Optional[str]:
        return self.address.street_address if self.address else None

    @property
    def latitude(self) -> Optional[float]:
        return float(self.address.latitude) if (self.address and self.address.latitude is not None) else None

    @property
    def longitude(self) -> Optional[float]:
        return float(self.address.longitude) if (self.address and self.address.longitude is not None) else None
