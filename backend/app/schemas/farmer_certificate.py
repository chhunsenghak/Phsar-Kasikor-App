from typing import Optional
from datetime import datetime
from pydantic import BaseModel

class FarmerCertificateBase(BaseModel):
    certificate_type: str
    issuing_body: Optional[str] = None
    document_url: str

class FarmerCertificateCreate(FarmerCertificateBase):
    pass

class FarmerCertificateReview(BaseModel):
    status: str # approved, rejected
    admin_feedback: Optional[str] = None

class FarmerCertificateOut(FarmerCertificateBase):
    id: str
    user_id: str
    status: str
    admin_feedback: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    created_at: datetime
    farmer_name: Optional[str] = None

    class Config:
        from_attributes = True
