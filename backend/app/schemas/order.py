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

class OrderUpdate(BaseModel):
    payment_status: Optional[PaymentStatus] = None
    order_status: Optional[OrderStatus] = None

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
    created_at: datetime
    items: List[OrderItemOut]

    model_config = ConfigDict(from_attributes=True)
