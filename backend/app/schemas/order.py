import enum
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field

class PaymentStatus(str, enum.Enum):
    PENDING = "PENDING"
    PAID = "PAID"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"

class OrderStatus(str, enum.Enum):
    PLACED = "PLACED"
    CONFIRMED = "CONFIRMED"
    SHIPPED = "SHIPPED"
    DELIVERED = "DELIVERED"
    CANCELLED = "CANCELLED"

class OrderItemBase(BaseModel):
    product_id: str
    quantity: float = Field(..., gt=0)

class OrderItemCreate(OrderItemBase):
    pass

class OrderItemOut(OrderItemBase):
    id: str
    order_id: str
    subtotal: float

    model_config = ConfigDict(from_attributes=True)

class OrderCreate(BaseModel):
    items: List[OrderItemCreate]
    payment_method: Optional[str] = "KHQR"
    delivery_method: Optional[str] = "DELIVERY"
    # Required when delivery_method is DELIVERY — where the buyer wants the
    # order dropped off. address_text is a human-readable label only; the
    # coordinates are what delivery tracking actually relies on.
    delivery_address_text: Optional[str] = None
    delivery_lat: Optional[float] = Field(None, ge=-90, le=90)
    delivery_lng: Optional[float] = Field(None, ge=-180, le=180)

class OrderUpdate(BaseModel):
    """
    Advances the order's fulfillment stage. payment_status is deliberately
    absent — a buyer or seller self-reporting payment defeats the point of
    verifying it; see the payments endpoints and Order.confirm-payment for
    the only legitimate ways payment_status changes.

    contact_phone/delivery_notes/actual_delivery_cost are only meaningful
    (and only stored) when this update transitions the order to SHIPPED —
    that's the moment a farmer actually knows who's carrying it and what it
    cost. actual_delivery_cost is a private record of what the farmer paid
    a transporter; it is never charged to the buyer and is separate from
    the order's own delivery_fee, which was already fixed at checkout.
    """
    order_status: OrderStatus
    contact_phone: Optional[str] = None
    delivery_notes: Optional[str] = None
    actual_delivery_cost: Optional[float] = None

class OrderOut(BaseModel):
    id: str
    buyer_id: str
    seller_id: str
    buyer_name: Optional[str] = None
    seller_name: Optional[str] = None
    total_amount: float
    currency: str
    payment_status: PaymentStatus
    order_status: OrderStatus
    payment_method: str
    delivery_method: str
    delivery_fee: float
    delivery_address_text: Optional[str] = None
    delivery_lat: Optional[float] = None
    delivery_lng: Optional[float] = None
    delivery_distance_km: Optional[float] = None
    delivery_weight_kg: Optional[float] = None
    created_at: datetime
    items: List[OrderItemOut]

    model_config = ConfigDict(from_attributes=True)
