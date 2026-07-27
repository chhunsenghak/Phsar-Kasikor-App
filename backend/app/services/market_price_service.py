from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.market_price import MarketPrice
from app.schemas.market_price import MarketPriceCreate, MarketPriceUpdate

def get_market_price(db: Session, price_id: str) -> Optional[MarketPrice]:
    return db.query(MarketPrice).filter(MarketPrice.id == price_id).first()

def get_market_prices(
    db: Session,
    skip: int = 0,
    limit: int = 100,
    commodity_name: Optional[str] = None,
    market_location: Optional[str] = None
) -> List[MarketPrice]:
    query = db.query(MarketPrice)
    if commodity_name:
        query = query.filter(MarketPrice.commodity_name.ilike(f"%{commodity_name}%"))
    if market_location:
        query = query.filter(MarketPrice.market_location.ilike(f"%{market_location}%"))
    return query.order_by(MarketPrice.recorded_date.desc()).offset(skip).limit(limit).all()

def create_market_price(db: Session, price_in: MarketPriceCreate) -> MarketPrice:
    db_price = MarketPrice(
        commodity_name=price_in.commodity_name,
        average_market_price=price_in.average_market_price,
        highest_price=price_in.highest_price,
        lowest_price=price_in.lowest_price,
        market_location=price_in.market_location,
        recorded_date=price_in.recorded_date
    )
    db.add(db_price)
    db.commit()
    db.refresh(db_price)
    return db_price

def update_market_price(db: Session, db_price: MarketPrice, price_update: MarketPriceUpdate) -> MarketPrice:
    update_data = price_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_price, field, value)
    db.commit()
    db.refresh(db_price)
    return db_price

def delete_market_price(db: Session, price_id: str) -> bool:
    db_price = get_market_price(db, price_id)
    if not db_price:
        return False
    db.delete(db_price)
    db.commit()
    return True
