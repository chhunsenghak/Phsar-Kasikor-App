from datetime import datetime
from pydantic import BaseModel
from typing import Optional
from app.schemas.product import ProductOut

class SavedCropCreate(BaseModel):
    product_id: str

class SavedCropOut(BaseModel):
    id: str
    user_id: str
    product_id: str
    created_at: datetime
    product: Optional[ProductOut] = None

    class Config:
        from_attributes = True
