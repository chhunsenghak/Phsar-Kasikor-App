from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.schemas.delivery import DeliveryCreate, DeliveryOut, DeliveryUpdate
from app.services import delivery_service

router = APIRouter()

@router.get("/", response_model=List[DeliveryOut])
def read_deliveries(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    _current_user: Any = Depends(deps.get_current_user)
) -> Any:
    """
    Retrieve all registered deliveries.
    """
    return delivery_service.get_deliveries(db, skip=skip, limit=limit)

@router.post("/", response_model=DeliveryOut, status_code=status.HTTP_201_CREATED)
def create_delivery(
    delivery_in: DeliveryCreate,
    db: Session = Depends(deps.get_db),
    _current_user: Any = Depends(deps.get_current_user)
) -> Any:
    """
    Register a new delivery track log.
    """
    return delivery_service.create_delivery(db, delivery_in=delivery_in)

@router.get("/{delivery_id}", response_model=DeliveryOut)
def read_delivery(
    delivery_id: str,
    db: Session = Depends(deps.get_db),
    _current_user: Any = Depends(deps.get_current_user)
) -> Any:
    """
    Retrieve details and current positions of a delivery.
    """
    db_delivery = delivery_service.get_delivery(db, delivery_id=delivery_id)
    if not db_delivery:
        raise HTTPException(status_code=404, detail="Delivery track not found")
    return db_delivery

@router.put("/{delivery_id}", response_model=DeliveryOut)
def update_delivery(
    delivery_id: str,
    delivery_update: DeliveryUpdate,
    db: Session = Depends(deps.get_db),
    _current_user: Any = Depends(deps.get_current_user)
) -> Any:
    """
    Update transporter details, delivery status, or live GPS coordinates.
    """
    db_delivery = delivery_service.get_delivery(db, delivery_id=delivery_id)
    if not db_delivery:
        raise HTTPException(status_code=404, detail="Delivery track not found")
    return delivery_service.update_delivery(db, db_delivery=db_delivery, delivery_update=delivery_update)

@router.delete("/{delivery_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_delivery(
    delivery_id: str,
    db: Session = Depends(deps.get_db),
    _current_user: Any = Depends(deps.get_current_user)
) -> None:
    """
    Cancel and delete a delivery track log.
    """
    deleted = delivery_service.delete_delivery(db, delivery_id=delivery_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Delivery track not found")
