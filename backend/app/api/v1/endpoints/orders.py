from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.models.user import User
from app.schemas.order import OrderCreate, OrderOut, OrderUpdate
from app.schemas.base import SuccessResponse
from app.core import errors, success
from app.services import order_service, contract_service

router = APIRouter()

@router.get("/", response_model=List[OrderOut])
def read_orders(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Retrieve all orders placed or received by the current user.
    """
    return order_service.get_orders_for_user(db, user_id=current_user.id, skip=skip, limit=limit)

@router.post("/", response_model=OrderOut, status_code=status.HTTP_201_CREATED)
def create_order(
    order_in: OrderCreate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Place a new product order. Decreases available quantities from inventory automatically.
    """
    try:
        return order_service.create_order(db, order_in=order_in, buyer_id=current_user.id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/admin/pending-payments", response_model=List[OrderOut])
def read_pending_khqr_payments(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Every KHQR order still waiting on payment confirmation — the admin queue
    for the manual-confirm fallback (see confirm_order_payment below).
    Admin-only, and must be declared before /{order_id} so "admin" doesn't
    get swallowed as an order_id path segment.
    """
    return order_service.get_pending_khqr_payments(db, skip=skip, limit=limit)

@router.get("/admin/all", response_model=List[OrderOut])
def read_all_orders(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Every order platform-wide, regardless of buyer/seller — the admin
    "wholesale history" view. Admin-only, and must be declared before
    /{order_id} so "admin" doesn't get swallowed as an order_id path segment.
    """
    return order_service.get_all_orders(db, skip=skip, limit=limit)

@router.get("/{order_id}", response_model=OrderOut)
def read_order(
    order_id: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Retrieve specific order transaction details. Only buyer or seller can read.
    """
    db_order = order_service.get_order(db, order_id=order_id)
    if not db_order:
        raise HTTPException(status_code=404, detail=errors.ORDER_NOT_FOUND)
    if db_order.buyer_id != current_user.id and db_order.seller_id != current_user.id:
        raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)
    return db_order

_ORDER_ERROR_STATUS = {
    "NOT_AUTHORIZED": 403,
    "INVALID_ORDER_STATUS_TRANSITION": 400,
    "PAYMENT_NOT_CONFIRMED": 400,
    "ORDER_ALREADY_PAID": 400,
}

@router.put("/{order_id}", response_model=OrderOut)
def update_order(
    order_id: str,
    order_update: OrderUpdate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Advance the order's fulfillment stage (PLACED -> CONFIRMED -> SHIPPED ->
    DELIVERED). Only the seller can do this — the buyer's only lever on
    order state is /cancel. A KHQR order cannot be CONFIRMED until its
    payment has actually been verified. If this order was created from a
    contract (see order_service.create_order_from_contract), reaching
    DELIVERED also completes that contract — kept here rather than inside
    order_service to avoid a circular import between it and
    contract_service.
    """
    db_order = order_service.get_order(db, order_id=order_id)
    if not db_order:
        raise HTTPException(status_code=404, detail=errors.ORDER_NOT_FOUND)
    try:
        updated_order = order_service.update_order_status(
            db, db_order=db_order, order_update=order_update, actor_id=current_user.id
        )
        if updated_order.order_status == "DELIVERED":
            contract_service.complete_contract_from_fulfillment(db, updated_order.id)
        return updated_order
    except Exception as e:
        code = str(e)
        raise HTTPException(status_code=_ORDER_ERROR_STATUS.get(code, 400), detail=code)

@router.post("/{order_id}/confirm-payment", response_model=OrderOut)
def confirm_order_payment(
    order_id: str,
    db: Session = Depends(deps.get_db),
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Support-only escape hatch for a KHQR order stuck PENDING despite really
    being paid. Payment tracking is otherwise fully automatic (every order
    read re-checks Bakong on its own, see order_service.get_order) — this
    exists only for the rare case that check can't recover on its own.
    Admin-only: every KHQR order pays into the platform's own merchant
    account, not the seller's, so only admin has any firsthand basis to
    override it — a buyer or seller confirming their own payment is exactly
    the hole this whole design closes.
    """
    db_order = order_service.get_order(db, order_id=order_id)
    if not db_order:
        raise HTTPException(status_code=404, detail=errors.ORDER_NOT_FOUND)
    try:
        return order_service.confirm_payment_by_admin(db, db_order=db_order)
    except Exception as e:
        code = str(e)
        raise HTTPException(status_code=_ORDER_ERROR_STATUS.get(code, 400), detail=code)


@router.post("/{order_id}/cancel", response_model=SuccessResponse)
def cancel_order(
    order_id: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Cancel an order and release reserved product stock. Only buyer or seller can cancel.
    """
    try:
        order_service.cancel_order(db, order_id=order_id, current_user_id=current_user.id)
        return success.make_success_response(success.ORDER_CANCELLED)
    except Exception as e:
        err_msg = str(e)
        if err_msg == "ORDER_NOT_FOUND":
            raise HTTPException(status_code=404, detail=errors.ORDER_NOT_FOUND)
        elif err_msg == "NOT_AUTHORIZED":
            raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)
        elif err_msg == "ORDER_CANNOT_BE_CANCELLED":
            raise HTTPException(status_code=400, detail=errors.ORDER_CANNOT_BE_CANCELLED)
        else:
            raise HTTPException(status_code=400, detail=err_msg)
