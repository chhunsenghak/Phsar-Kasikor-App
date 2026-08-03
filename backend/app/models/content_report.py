import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import Base

class ContentReport(Base):
    __tablename__ = "content_reports"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    reporter_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    product_id = Column(String(36), ForeignKey("products.id"), nullable=True, index=True)
    post_id = Column(String(36), ForeignKey("forum_posts.id"), nullable=True, index=True)
    reason = Column(Text, nullable=False)
    status = Column(String, nullable=False, default="pending") # pending, dismissed, resolved
    admin_feedback = Column(Text, nullable=True)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )
    reviewed_at = Column(DateTime, nullable=True)

    # Relationships
    reporter = relationship("User", backref="reported_content")
    product = relationship("Product", backref="reports")
    post = relationship("ForumPost", backref="reports")
