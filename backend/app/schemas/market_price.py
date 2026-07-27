from datetime import date
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field

class MarketPriceBase(BaseModel):
    commodity_name: str
    average_market_price: float = Field(..., gt=0)
    highest_price: Optional[float] = Field(None, gt=0)
    lowest_price: Optional[float] = Field(None, gt=0)
    market_location: str
    recorded_date: date

class MarketPriceCreate(MarketPriceBase):
    pass

class MarketPriceUpdate(BaseModel):
    commodity_name: Optional[str] = None
    average_market_price: Optional[float] = Field(None, gt=0)
    highest_price: Optional[float] = Field(None, gt=0)
    lowest_price: Optional[float] = Field(None, gt=0)
    market_location: Optional[str] = None
    recorded_date: Optional[date] = None

class MarketPriceOut(MarketPriceBase):
    id: str

    model_config = ConfigDict(from_attributes=True)
