from sqlalchemy import Column, Integer, String, DateTime
from datetime import datetime, timezone
from sqlalchemy.orm import relationship

from app.models.base import Base

class Role(Base):
    __tablename__ = "roles"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, unique=True, index=True, nullable=False)
    description = Column(String, nullable=True)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Many-to-many relationship with User
    users = relationship("User", secondary="user_roles", back_populates="roles")
