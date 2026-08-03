from typing import Any
from datetime import datetime
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.api import deps
from app.core.database import get_db
from app.models.user import User
from app.models.product import Product
from app.models.order import Order
from app.schemas.analytics import FarmerSalesAnalyticsOut, MonthlyRevenueItem

router = APIRouter()

@router.get("/farmer-sales", response_model=FarmerSalesAnalyticsOut)
def get_farmer_sales_analytics(
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Compute total sales revenue, active product count, order acceptance stats, and monthly breakdown for farmer.
    """
    # Active products owned by farmer
    active_listings = db.query(func.count(Product.id)).filter(
        Product.seller_id == current_user.id,
        Product.status == "active"
    ).scalar() or 0

    # Orders received by farmer
    orders = db.query(Order).filter(Order.seller_id == current_user.id).all()
    confirmed_orders = [o for o in orders if o.status in ["CONFIRMED", "DELIVERED", "ACCEPTED", "PAID"]]

    total_yearly_sales = sum(float(o.total_price) for o in confirmed_orders)
    orders_accepted = len(confirmed_orders)

    # Conversion rate approximation
    total_orders_received = len(orders)
    conversion_rate = (
        f"{(orders_accepted / total_orders_received * 100):.1f}%"
        if total_orders_received > 0
        else "0.0%"
    )

    # Monthly revenue breakdown (last 7 months or current year)
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    revenue_by_month = {m: 0.0 for m in months}

    for o in confirmed_orders:
        if o.created_at:
            m_str = months[o.created_at.month - 1]
            revenue_by_month[m_str] += float(o.total_price)

    current_month_idx = datetime.now().month
    display_months = months[:current_month_idx] if current_month_idx >= 7 else months[:7]

    monthly_revenues = [
        MonthlyRevenueItem(month=m, value=round(revenue_by_month[m], 2))
        for m in display_months
    ]

    return FarmerSalesAnalyticsOut(
        total_yearly_sales=round(total_yearly_sales, 2),
        active_listings=active_listings,
        conversion_rate=conversion_rate,
        orders_accepted=orders_accepted,
        monthly_revenues=monthly_revenues
    )
