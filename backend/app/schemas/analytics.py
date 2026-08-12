from typing import List
from pydantic import BaseModel

class CurrencyAmount(BaseModel):
    currency: str
    amount: float

class MonthlyRevenueItem(BaseModel):
    month: str
    currency: str
    value: float

class FarmerSalesAnalyticsOut(BaseModel):
    # A farmer's orders can be placed in either USD or KHR — summing them
    # into one blended number would be meaningless (there's no exchange
    # rate anywhere in this app to convert between them), so revenue is
    # reported per currency instead. Usually just one entry.
    revenue_by_currency: List[CurrencyAmount]
    active_listings: int
    conversion_rate: str
    orders_accepted: int
    monthly_revenues: List[MonthlyRevenueItem]
