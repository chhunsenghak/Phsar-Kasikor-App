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

class OrderUpdate(BaseModel):
    payment_status: Optional[PaymentStatus] = None
    order_status: Optional[OrderStatus] = None

class OrderOut(BaseModel):
    id: str
    buyer_id: str
    seller_id: str
    total_amount: float
    payment_status: PaymentStatus
    order_status: OrderStatus
    created_at: datetime
    items: List[OrderItemOut]

    model_config = ConfigDict(from_attributes=True)
