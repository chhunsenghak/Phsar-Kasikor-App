from typing import Optional
from datetime import datetime
from pydantic import BaseModel, ConfigDict

class DisputeCreate(BaseModel):
    order_id: str
    reason: str

class DisputeResolve(BaseModel):
    status: str  # RESOLVED_REFUND, RESOLVED_REJECTED
    resolution_note: Optional[str] = None
    refund_amount: Optional[float] = None

class DisputeOut(BaseModel):
    id: str
    order_id: str
    raised_by: str
    raiser_name: Optional[str] = None
    reason: str
    status: str
    resolution_note: Optional[str] = None
    refund_amount: Optional[float] = None
    created_at: datetime
    resolved_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
