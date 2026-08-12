from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field

class DeliveryBase(BaseModel):
    order_id: str
    transporter_name: Optional[str] = None
    current_location_lat: Optional[float] = Field(None, ge=-90, le=90)
    current_location_lng: Optional[float] = Field(None, ge=-180, le=180)
    delivery_status: str = "dispatched"
    estimated_time_of_arrival: Optional[datetime] = None
    contact_phone: Optional[str] = None
    delivery_notes: Optional[str] = None
    actual_delivery_cost: Optional[float] = None

class DeliveryCreate(DeliveryBase):
    pass

class DeliveryUpdate(BaseModel):
    transporter_name: Optional[str] = None
    current_location_lat: Optional[float] = Field(None, ge=-90, le=90)
    current_location_lng: Optional[float] = Field(None, ge=-180, le=180)
    delivery_status: Optional[str] = None
    estimated_time_of_arrival: Optional[datetime] = None
    contact_phone: Optional[str] = None
    delivery_notes: Optional[str] = None
    actual_delivery_cost: Optional[float] = None

class DeliveryOut(DeliveryBase):
    id: str

    model_config = ConfigDict(from_attributes=True)

class DeliveryLocationUpdate(BaseModel):
    current_location_lat: float = Field(..., ge=-90, le=90)
    current_location_lng: float = Field(..., ge=-180, le=180)
