from typing import Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.schemas.market_price import MarketPriceCreate, MarketPriceOut, MarketPriceUpdate
from app.services import market_price_service

router = APIRouter()

@router.get("/", response_model=List[MarketPriceOut])
def read_market_prices(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    commodity_name: Optional[str] = None,
    market_location: Optional[str] = None
) -> Any:
    """
    Retrieve benchmark market prices.
    """
    return market_price_service.get_market_prices(
        db, skip=skip, limit=limit, commodity_name=commodity_name, market_location=market_location
    )

@router.post("/", response_model=MarketPriceOut, status_code=status.HTTP_201_CREATED)
def create_market_price(
    price_in: MarketPriceCreate,
    db: Session = Depends(deps.get_db),
    _current_user: Any = Depends(deps.get_current_user)
) -> Any:
    """
    Log a new market price benchmark.
    """
    return market_price_service.create_market_price(db, price_in=price_in)

@router.get("/{price_id}", response_model=MarketPriceOut)
def read_market_price(
    price_id: str,
    db: Session = Depends(deps.get_db)
) -> Any:
    """
    Retrieve market price benchmark details.
    """
    db_price = market_price_service.get_market_price(db, price_id=price_id)
    if not db_price:
        raise HTTPException(status_code=404, detail="Market price entry not found")
    return db_price

@router.put("/{price_id}", response_model=MarketPriceOut)
def update_market_price(
    price_id: str,
    price_update: MarketPriceUpdate,
    db: Session = Depends(deps.get_db),
    _current_user: Any = Depends(deps.get_current_user)
) -> Any:
    """
    Update a market price benchmark.
    """
    db_price = market_price_service.get_market_price(db, price_id=price_id)
    if not db_price:
        raise HTTPException(status_code=404, detail="Market price entry not found")
    return market_price_service.update_market_price(db, db_price=db_price, price_update=price_update)

@router.delete("/{price_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_market_price(
    price_id: str,
    db: Session = Depends(deps.get_db),
    _current_user: Any = Depends(deps.get_current_user)
) -> None:
    """
    Delete a market price benchmark.
    """
    deleted = market_price_service.delete_market_price(db, price_id=price_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Market price entry not found")
