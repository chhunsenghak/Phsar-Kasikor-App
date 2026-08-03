from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel

class CooperativeMemberOut(BaseModel):
    id: str
    cooperative_id: str
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
