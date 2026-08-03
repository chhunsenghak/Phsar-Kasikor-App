from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel

class ForumCommentBase(BaseModel):
    content: str

class ForumCommentCreate(ForumCommentBase):
    pass

class ForumCommentOut(ForumCommentBase):
    id: str
    post_id: str
    author_id: str
    author_name: Optional[str] = "Anonymous"
    created_at: datetime

    class Config:
        from_attributes = True


class ForumPostBase(BaseModel):
    title: str
    content: str
    category: Optional[str] = "General"

class ForumPostCreate(ForumPostBase):
    pass

class ForumPostOut(ForumPostBase):
    id: str
    author_id: str
    author_name: Optional[str] = "Anonymous"
    title: str
    content: str
    category: str
    likes_count: int
    created_at: datetime
    updated_at: datetime
    comments_count: Optional[int] = 0

    class Config:
        from_attributes = True


class ForumPostDetailOut(ForumPostOut):
    comments: List[ForumCommentOut] = []
