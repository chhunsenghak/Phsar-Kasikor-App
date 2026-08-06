from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel

class CooperativeMemberInvite(BaseModel):
    # Either the invitee's phone number or email — whichever the leader has on hand.
    identifier: str

class CooperativeMemberStatusUpdate(BaseModel):
    status: str  # active, rejected

class StockSummaryItem(BaseModel):
    crop_name: str
    unit: str
    total_quantity: float
    farms_count: int

class CooperativeMemberOut(BaseModel):
    id: str
    cooperative_id: str
    cooperative_name: Optional[str] = None
    farmer_id: str
    farmer_name: Optional[str] = None
    location: Optional[str] = None
    status: str
    products_count: Optional[int] = 0
    joined_at: datetime

    class Config:
        from_attributes = True

class CooperativeOut(BaseModel):
    id: str
    leader_id: str
    name: str
    province: Optional[str] = None
    description: Optional[str] = None
    members_count: Optional[int] = 0
    created_at: datetime

    class Config:
        from_attributes = True
