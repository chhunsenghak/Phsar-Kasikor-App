from typing import Optional
from datetime import datetime
from pydantic import BaseModel

class ContentReportCreate(BaseModel):
    product_id: Optional[str] = None
    post_id: Optional[str] = None
    reason: str

class ContentReportResolve(BaseModel):
    status: str # dismissed, resolved
    admin_feedback: Optional[str] = None

class ContentReportOut(BaseModel):
    id: str
    reporter_id: str
    reporter_name: Optional[str] = None
    product_id: Optional[str] = None
    product_name: Optional[str] = None
    post_id: Optional[str] = None
    post_title: Optional[str] = None
    reason: str
    status: str
    admin_feedback: Optional[str] = None
    created_at: datetime
    reviewed_at: Optional[datetime] = None

    class Config:
        from_attributes = True
