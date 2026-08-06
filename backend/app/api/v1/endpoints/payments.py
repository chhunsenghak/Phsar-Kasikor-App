from typing import Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api import deps
from app.core import errors
from app.core.database import get_db
from app.models.user import User
from app.models.order import Order
from app.schemas.payment import KHQRGenerateRequest, KHQROut, PaymentStatusOut
from app.services import khqr_service

router = APIRouter()

@router.post("/khqr", response_model=KHQROut)
def generate_khqr_for_orders(
    request: KHQRGenerateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Generate a real, scannable KHQR code covering the given orders. All
    orders must belong to the current user (as buyer), share one currency,
    and still be unpaid — a KHQR encodes exactly one amount in one currency.
    """
    if not request.order_ids:
        raise HTTPException(status_code=400, detail=errors.ORDER_NOT_FOUND)

    orders = db.query(Order).filter(Order.id.in_(request.order_ids)).all()
    if len(orders) != len(request.order_ids):
        raise HTTPException(status_code=404, detail=errors.ORDER_NOT_FOUND)

    for o in orders:
        if o.buyer_id != current_user.id:
            raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)
        if o.payment_status == "PAID":
            raise HTTPException(status_code=400, detail=errors.ORDER_ALREADY_PAID)

    currencies = {o.currency for o in orders}
    if len(currencies) != 1:
        raise HTTPException(status_code=400, detail=errors.MULTIPLE_CURRENCIES_IN_ORDER)
    currency = currencies.pop()
    total = sum(float(o.total_amount) for o in orders)

    # A KHQR bill_number is a short free-text reference, not a real join key —
    # the frontend already knows which order_ids it asked to pay.
    bill_number = orders[0].id[:8].upper()

    result = khqr_service.generate_khqr(amount=total, currency=currency, bill_number=bill_number)
    return KHQROut(**result)

@router.get("/khqr/{md5_hash}/status", response_model=PaymentStatusOut)
def get_khqr_payment_status(
    md5_hash: str,
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Best-effort check of whether a generated KHQR has been paid. Returns
    "unavailable" (not "unpaid") whenever verification can't actually be
    performed, so the client knows to fall back to manual confirmation
    instead of assuming payment failed.
    """
    paid = khqr_service.check_payment_status(md5_hash)
    if paid is None:
        return PaymentStatusOut(status="unavailable")
    return PaymentStatusOut(status="paid" if paid else "unpaid")
