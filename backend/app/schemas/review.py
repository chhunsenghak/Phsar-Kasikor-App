from typing import Optional
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field

class ReviewCreate(BaseModel):
    order_id: str
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = None

class ReviewOut(BaseModel):
    id: str
    order_id: str
    reviewer_id: str
    reviewer_name: Optional[str] = None
    reviewee_id: str
    product_id: Optional[str] = None
    product_name: Optional[str] = None
    rating: int
    comment: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class ReviewSummaryOut(BaseModel):
    average_rating: float
    review_count: int

class ReviewableOrderOut(BaseModel):
    order_id: str
    seller_id: str
    seller_name: Optional[str] = None
    product_name: Optional[str] = None
    delivered_at: Optional[datetime] = None
