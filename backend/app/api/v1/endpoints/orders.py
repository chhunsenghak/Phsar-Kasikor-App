from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.models.user import User
from app.schemas.order import OrderCreate, OrderOut, OrderUpdate
from app.schemas.base import SuccessResponse
from app.core import errors, success
from app.services import order_service

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
    payment has actually been verified.
    """
    db_order = order_service.get_order(db, order_id=order_id)
    if not db_order:
        raise HTTPException(status_code=404, detail=errors.ORDER_NOT_FOUND)
    try:
        return order_service.update_order_status(
            db, db_order=db_order, order_update=order_update, actor_id=current_user.id
        )
    except Exception as e:
        code = str(e)
        raise HTTPException(status_code=_ORDER_ERROR_STATUS.get(code, 400), detail=code)

@router.post("/{order_id}/confirm-payment", response_model=OrderOut)
def confirm_order_payment(
    order_id: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Seller-side manual confirmation that payment for this order was
    received. This is the fallback for when automatic Bakong verification
    isn't configured — it deliberately cannot be called by the buyer, since
    letting the payer confirm their own payment is exactly the hole this
    closes.
    """
    db_order = order_service.get_order(db, order_id=order_id)
    if not db_order:
        raise HTTPException(status_code=404, detail=errors.ORDER_NOT_FOUND)
    try:
        return order_service.confirm_payment_by_seller(db, db_order=db_order, actor_id=current_user.id)
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
