import uuid
from sqlalchemy import Column, String, Numeric, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from app.models.base import Base

class Delivery(Base):
    __tablename__ = "deliveries"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    order_id = Column(String(36), ForeignKey("orders.id"), nullable=False)
    transporter_name = Column(String, nullable=True)
    current_location_lat = Column(Numeric(10, 8), nullable=True)
    current_location_lng = Column(Numeric(11, 8), nullable=True)
    delivery_status = Column(String, default="dispatched", nullable=False) # dispatched, in_transit, arrived, failed
    estimated_time_of_arrival = Column(DateTime, nullable=True)

    # Relationships
    order = relationship("Order", backref="deliveries")
