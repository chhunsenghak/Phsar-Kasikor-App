import uuid
from sqlalchemy import Column, String, Numeric, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship

from app.models.base import Base

class Delivery(Base):
    __tablename__ = "deliveries"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    order_id = Column(String(36), ForeignKey("orders.id"), nullable=False)
    transporter_name = Column(String, nullable=True)
    current_location_lat = Column(Numeric(10, 8), nullable=True)
    current_location_lng = Column(Numeric(11, 8), nullable=True)
    delivery_status = Column(String, default="pending", nullable=False) # pending, in_transit, arrived, failed
    estimated_time_of_arrival = Column(DateTime, nullable=True)
    # Set by the farmer when they mark the order SHIPPED. contact_phone and
    # delivery_notes are shown to the buyer (how to reach/expect the
    # delivery); actual_delivery_cost is a private record of what the
    # farmer paid a transporter and is never surfaced to the buyer or
    # charged on top of the order total.
    contact_phone = Column(String, nullable=True)
    delivery_notes = Column(Text, nullable=True)
    actual_delivery_cost = Column(Numeric(10, 2), nullable=True)

    # Relationships
    order = relationship("Order", backref="deliveries")
