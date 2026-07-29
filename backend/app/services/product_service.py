from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.product import Product
from app.schemas.product import ProductCreate, ProductUpdate

def get_product(db: Session, product_id: str) -> Optional[Product]:
    return db.query(Product).filter(Product.id == product_id).first()

def get_products(
    db: Session,
    skip: int = 0,
    limit: int = 100,
    category_id: Optional[str] = None,
    seller_id: Optional[str] = None
) -> List[Product]:
    query = db.query(Product).filter(Product.status != "deleted")
    if category_id:
        query = query.filter(Product.category_id == category_id)
    if seller_id:
        query = query.filter(Product.seller_id == seller_id)
    return query.offset(skip).limit(limit).all()

def create_product(db: Session, product_in: ProductCreate, seller_id: str) -> Product:
    db_product = Product(
        seller_id=seller_id,
        product_name=product_in.product_name,
        category_id=product_in.category_id,
        price_per_unit=product_in.price_per_unit,
        unit_type=product_in.unit_type,
        currency=product_in.currency,
        quantity_available=product_in.quantity_available,
        harvest_date=product_in.harvest_date,
        quality_certification_metadata=product_in.quality_certification_metadata,
        status=product_in.status,
        image_url=product_in.image_url
    )
    db.add(db_product)
    db.commit()
    db.refresh(db_product)
    return db_product

def update_product(db: Session, db_product: Product, product_update: ProductUpdate) -> Product:
    update_data = product_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_product, field, value)
    db.commit()
    db.refresh(db_product)
    return db_product

def delete_product(db: Session, product_id: str) -> bool:
    db_product = get_product(db, product_id)
    if not db_product:
        return False
    db_product.status = "deleted"
    db.commit()
    return True
