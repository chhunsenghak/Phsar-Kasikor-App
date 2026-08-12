from typing import Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api import deps
from app.core import errors
from app.core.database import get_db
from app.models.user import User
from app.models.order import Order
from app.schemas.payment import KHQRGenerateRequest, KHQROut, PaymentStatusOut, PaymentConfirmOut
from app.services import khqr_service, order_service

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
        if o.order_status == "CANCELLED":
            raise HTTPException(status_code=400, detail=errors.ORDER_ALREADY_CANCELLED)

    # Bakong's dynamic KHQR embeds a fresh timestamp on every build, so
    # re-generating for the same orders — a hot reload, re-opening the
    # checkout screen, anything that re-runs this call — would mint a brand
    # new md5 and silently orphan a QR the buyer may already have scanned
    # and paid. If every requested order already carries the same pending
    # QR, hand back that one instead: re-rendering its image is pure/local
    # and never touches Bakong, so it can't change the md5.
    existing_md5s = {o.khqr_md5 for o in orders}
    existing_qr_strings = {o.khqr_qr_string for o in orders}
    if len(existing_md5s) == 1 and len(existing_qr_strings) == 1 and None not in existing_qr_strings:
        qr_string = existing_qr_strings.pop()
        return KHQROut(
            qr_string=qr_string,
            md5=existing_md5s.pop(),
            qr_image_base64=khqr_service.render_qr_image(qr_string),
        )

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
        o.khqr_qr_string = result["qr_string"]
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
    performed, so the client knows the difference between "checked, not
    paid yet" and "couldn't check at all". This is read-only — it never
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
    this md5. This is also called automatically every time an order is read
    (see order_service.get_order), so payment tracking works even if the
    buyer never taps anything on this endpoint themselves.
    """
    orders = db.query(Order).filter(Order.khqr_md5 == md5_hash, Order.payment_status == "PENDING").all()
    if not orders:
        raise HTTPException(status_code=404, detail=errors.ORDER_NOT_FOUND)
    for o in orders:
        if o.buyer_id != current_user.id:
            raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)

    status_str, settled = order_service.verify_and_settle_khqr(db, md5_hash)
    if status_str != "paid":
        return PaymentConfirmOut(status=status_str)
    return PaymentConfirmOut(status="paid", confirmed_order_ids=[o.id for o in settled])
