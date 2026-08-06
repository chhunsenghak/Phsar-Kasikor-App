import uuid
from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, String, Text, Integer, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.models.base import Base

class ForumPost(Base):
    __tablename__ = "forum_posts"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    author_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    category = Column(String, nullable=False, default="General") # General, Pest Control, Organic Farming, Market Prices
    likes_count = Column(Integer, nullable=False, default=0)
    # Set by admin moderation when a content report against this post is
    # resolved — hidden posts are excluded from listings/detail instead of
    # being hard-deleted, so comments/history aren't destroyed.
    is_hidden = Column(Boolean, nullable=False, default=False)
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
    author = relationship("User", backref="forum_posts")
    comments = relationship("ForumComment", back_populates="post", cascade="all, delete-orphan")


class ForumComment(Base):
    __tablename__ = "forum_comments"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    post_id = Column(String(36), ForeignKey("forum_posts.id"), nullable=False, index=True)
    author_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    content = Column(Text, nullable=False)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Relationships
    post = relationship("ForumPost", back_populates="comments")
    author = relationship("User", backref="forum_comments")
