from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.core import errors
from app.models.user import User
from app.schemas.delivery import DeliveryCreate, DeliveryOut, DeliveryUpdate, DeliveryLocationUpdate
from app.services import delivery_service, order_service

router = APIRouter()

# Everyday tracking (read the destination + live position, push a location
# ping) goes through the /order/{order_id} routes below, scoped to that
# order's buyer/seller. These generic-by-id routes are kept for platform
# staff only — a Delivery row's id carries no ownership info on its own,
# so anyone holding one could otherwise read/edit any order's tracking data.

@router.get("/", response_model=List[DeliveryOut])
def read_deliveries(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Retrieve all registered deliveries. Admin only.
    """
    return delivery_service.get_deliveries(db, skip=skip, limit=limit)

@router.post("/", response_model=DeliveryOut, status_code=status.HTTP_201_CREATED)
def create_delivery(
    delivery_in: DeliveryCreate,
    db: Session = Depends(deps.get_db),
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Register a delivery track log by hand. Admin only — the normal flow
    creates one automatically when an order with delivery_method=DELIVERY
    is placed.
    """
    return delivery_service.create_delivery(db, delivery_in=delivery_in)

@router.get("/{delivery_id}", response_model=DeliveryOut)
def read_delivery(
    delivery_id: str,
    db: Session = Depends(deps.get_db),
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Retrieve details and current position of a delivery by its own id.
    Admin only.
    """
    db_delivery = delivery_service.get_delivery(db, delivery_id=delivery_id)
    if not db_delivery:
        raise HTTPException(status_code=404, detail=errors.DELIVERY_NOT_FOUND)
    return db_delivery

@router.put("/{delivery_id}", response_model=DeliveryOut)
def update_delivery(
    delivery_id: str,
    delivery_update: DeliveryUpdate,
    db: Session = Depends(deps.get_db),
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Update transporter details, delivery status, or GPS coordinates by hand.
    Admin only — sellers use PUT /order/{order_id}/location day-to-day.
    """
    db_delivery = delivery_service.get_delivery(db, delivery_id=delivery_id)
    if not db_delivery:
        raise HTTPException(status_code=404, detail=errors.DELIVERY_NOT_FOUND)
    return delivery_service.update_delivery(db, db_delivery=db_delivery, delivery_update=delivery_update)

@router.delete("/{delivery_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_delivery(
    delivery_id: str,
    db: Session = Depends(deps.get_db),
    _current_user: User = Depends(deps.get_current_admin_user)
) -> None:
    """
    Remove a delivery track log. Admin only.
    """
    deleted = delivery_service.delete_delivery(db, delivery_id=delivery_id)
    if not deleted:
        raise HTTPException(status_code=404, detail=errors.DELIVERY_NOT_FOUND)


@router.get("/order/{order_id}", response_model=DeliveryOut)
def read_delivery_for_order(
    order_id: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    The live tracking record for one order — destination lives on the
    order itself (GET /orders/{order_id}); this is the transporter's last
    known position and delivery-stage status. Buyer or seller only.
    """
    db_order = order_service.get_order(db, order_id=order_id)
    if not db_order:
        raise HTTPException(status_code=404, detail=errors.ORDER_NOT_FOUND)
    if current_user.id not in (db_order.buyer_id, db_order.seller_id):
        raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)

    db_delivery = delivery_service.get_delivery_for_order(db, order_id=order_id)
    if not db_delivery:
        raise HTTPException(status_code=404, detail=errors.DELIVERY_NOT_FOUND)
    return db_delivery

@router.put("/order/{order_id}/location", response_model=DeliveryOut)
def update_delivery_location_for_order(
    order_id: str,
    location: DeliveryLocationUpdate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Push a live position ping while fulfilling an order. Seller only — the
    seller is the one physically making (or arranging) the delivery, so
    they're the only legitimate source of "where's the shipment now."
    """
    db_order = order_service.get_order(db, order_id=order_id)
    if not db_order:
        raise HTTPException(status_code=404, detail=errors.ORDER_NOT_FOUND)
    if current_user.id != db_order.seller_id:
        raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)

    db_delivery = delivery_service.get_delivery_for_order(db, order_id=order_id)
    if not db_delivery:
        raise HTTPException(status_code=404, detail=errors.DELIVERY_NOT_FOUND)
    return delivery_service.update_delivery_location(
        db, db_delivery=db_delivery, lat=location.current_location_lat, lng=location.current_location_lng
    )
