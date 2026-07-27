import uuid
from sqlalchemy import Column, String, Numeric, Date

from app.models.base import Base

class MarketPrice(Base):
    __tablename__ = "market_prices"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    commodity_name = Column(String, nullable=False)
    average_market_price = Column(Numeric(10, 2), nullable=False)
    highest_price = Column(Numeric(10, 2), nullable=True)
    lowest_price = Column(Numeric(10, 2), nullable=True)
    market_location = Column(String, nullable=False)
    recorded_date = Column(Date, nullable=False)
