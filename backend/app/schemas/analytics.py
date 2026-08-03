from typing import List, Dict, Any
from pydantic import BaseModel

class MonthlyRevenueItem(BaseModel):
    month: str
    value: float

class FarmerSalesAnalyticsOut(BaseModel):
    total_yearly_sales: float
    active_listings: int
    conversion_rate: str
    orders_accepted: int
    monthly_revenues: List[MonthlyRevenueItem]
