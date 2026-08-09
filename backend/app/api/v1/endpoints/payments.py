from typing import Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api import deps
from app.core import errors
from app.core.database import get_db
from app.models.user import User
from app.models.order import Order
from app.schemas.payment import KHQRGenerateRequest, KHQROut, PaymentStatusOut, PaymentConfirmOut
from app.schemas.notification import NotificationCreate
from app.services import khqr_service, notification_service

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

    # Link this QR to the orders it covers so a later status check/confirm
    # on its md5 knows which orders to settle — without this, a "paid"
    # verification has nothing to act on.
    for o in orders:
        o.khqr_md5 = result["md5"]
    db.commit()

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
    instead of assuming payment failed. This is read-only — it never
    updates an order; use POST /khqr/{md5_hash}/confirm for that.
    """
    paid = khqr_service.check_payment_status(md5_hash)
    if paid is None:
        return PaymentStatusOut(status="unavailable")
    return PaymentStatusOut(status="paid" if paid else "unpaid")

@router.post("/khqr/{md5_hash}/confirm", response_model=PaymentConfirmOut)
def confirm_khqr_payment(
    md5_hash: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    The only way payment_status ever becomes PAID off the back of a KHQR
    scan: re-verifies against Bakong (never trusts the buyer's say-so) and,
    only on a confirmed "paid", flips every still-PENDING order linked to
    this md5. If verification isn't available (no bearer token configured,
    or a transient failure), nothing changes — the seller's manual
    confirm-payment action is the fallback for that case.
    """
    orders = db.query(Order).filter(Order.khqr_md5 == md5_hash, Order.payment_status == "PENDING").all()
    if not orders:
        raise HTTPException(status_code=404, detail=errors.ORDER_NOT_FOUND)
    for o in orders:
        if o.buyer_id != current_user.id:
            raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)

    paid = khqr_service.check_payment_status(md5_hash)
    if paid is not True:
        return PaymentConfirmOut(status="unavailable" if paid is None else "unpaid")

    confirmed_ids = []
    for o in orders:
        o.payment_status = "PAID"
        confirmed_ids.append(o.id)
    db.commit()

    for o in orders:
        try:
            notification_service.create_notification(
                db,
                notification_in=NotificationCreate(
                    user_id=o.seller_id,
                    title="Payment Received",
                    message=f"Order #{o.id[:8].upper()} has been paid via KHQR.",
                    is_read=False
                )
            )
        except Exception:
            pass

    return PaymentConfirmOut(status="paid", confirmed_order_ids=confirmed_ids)
