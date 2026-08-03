from typing import Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.models.user import User
from app.schemas.product import ProductCreate, ProductOut, ProductUpdate
from app.schemas.base import SuccessResponse
from app.core import errors, success
from app.services import product_service

router = APIRouter()

@router.get("/", response_model=List[ProductOut])
def read_products(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    category_id: Optional[str] = None,
    seller_id: Optional[str] = None,
    search: Optional[str] = None,
    min_price: Optional[float] = None,
    max_price: Optional[float] = None,
    province: Optional[str] = None
) -> Any:
    """
    Retrieve all products. Filter by category, seller, search keyword, price range, or province location.
    """
    return product_service.get_products(
        db,
        skip=skip,
        limit=limit,
        category_id=category_id,
        seller_id=seller_id,
        search=search,
        min_price=min_price,
        max_price=max_price,
        province=province
    )


@router.post("/", response_model=ProductOut, status_code=status.HTTP_201_CREATED)
def create_product(
    product_in: ProductCreate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Create a new product listing.
    """
    return product_service.create_product(db, product_in=product_in, seller_id=current_user.id)

@router.get("/{product_id}", response_model=ProductOut)
def read_product(
    product_id: str,
    db: Session = Depends(deps.get_db)
) -> Any:
    """
    Retrieve product details.
    """
    db_product = product_service.get_product(db, product_id=product_id)
    if not db_product:
        raise HTTPException(status_code=404, detail=errors.PRODUCT_NOT_FOUND)
    return db_product

@router.put("/{product_id}", response_model=ProductOut)
def update_product(
    product_id: str,
    product_update: ProductUpdate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Update a product listing. Only the owner can modify.
    """
    db_product = product_service.get_product(db, product_id=product_id)
    if not db_product:
        raise HTTPException(status_code=404, detail=errors.PRODUCT_NOT_FOUND)
    if db_product.seller_id != current_user.id:
        raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)
    return product_service.update_product(db, db_product=db_product, product_update=product_update)

@router.delete("/{product_id}", response_model=SuccessResponse, status_code=status.HTTP_200_OK)
def delete_product(
    product_id: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Delete a product listing. Only the owner can delete.
    """
    db_product = product_service.get_product(db, product_id=product_id)
    if not db_product:
        raise HTTPException(status_code=404, detail=errors.PRODUCT_NOT_FOUND)
    if db_product.seller_id != current_user.id:
        raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)
        
    # Check if this product is linked to any contracts or orders
    from app.models.contract import ContractItem
    from app.models.order_item import OrderItem
    
    contract_exists = db.query(ContractItem).filter(ContractItem.product_id == product_id).first()
    order_exists = db.query(OrderItem).filter(OrderItem.product_id == product_id).first()
    if contract_exists or order_exists:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=errors.PRODUCT_HAS_RELATED_INFO
        )

    product_service.delete_product(db, product_id=product_id)
    return success.make_success_response(success.PRODUCT_DELETED)
