from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.delivery import Delivery
from app.schemas.delivery import DeliveryCreate, DeliveryUpdate

def get_delivery(db: Session, delivery_id: str) -> Optional[Delivery]:
    return db.query(Delivery).filter(Delivery.id == delivery_id).first()

def get_delivery_for_order(db: Session, order_id: str) -> Optional[Delivery]:
    return db.query(Delivery).filter(Delivery.order_id == order_id).first()

def update_delivery_location(db: Session, db_delivery: Delivery, lat: float, lng: float) -> Delivery:
    db_delivery.current_location_lat = lat
    db_delivery.current_location_lng = lng
    db.commit()
    db.refresh(db_delivery)
    return db_delivery

def get_deliveries(db: Session, skip: int = 0, limit: int = 100) -> List[Delivery]:
    return db.query(Delivery).offset(skip).limit(limit).all()

def create_delivery(db: Session, delivery_in: DeliveryCreate) -> Delivery:
    db_delivery = Delivery(
        order_id=delivery_in.order_id,
        transporter_name=delivery_in.transporter_name,
        current_location_lat=delivery_in.current_location_lat,
        current_location_lng=delivery_in.current_location_lng,
        delivery_status=delivery_in.delivery_status,
        estimated_time_of_arrival=delivery_in.estimated_time_of_arrival
    )
    db.add(db_delivery)
    db.commit()
    db.refresh(db_delivery)
    return db_delivery

def update_delivery(db: Session, db_delivery: Delivery, delivery_update: DeliveryUpdate) -> Delivery:
    update_data = delivery_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_delivery, field, value)
    db.commit()
    db.refresh(db_delivery)
    return db_delivery

def delete_delivery(db: Session, delivery_id: str) -> bool:
    db_delivery = get_delivery(db, delivery_id)
    if not db_delivery:
        return False
    db.delete(db_delivery)
    db.commit()
    return True
