from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.category import Category
from app.schemas.category import CategoryCreate, CategoryUpdate

def get_category(db: Session, category_id: str) -> Optional[Category]:
    return db.query(Category).filter(Category.id == category_id).first()

def get_categories(
    db: Session,
    skip: int = 0,
    limit: int = 100,
) -> List[Category]:
    query = db.query(Category)
    return query.offset(skip).limit(limit).all()

def create_category(db: Session, category_in: CategoryCreate) -> Category:
    db_category = Category(
        name=category_in.name,
        description=category_in.description
    )
    db.add(db_category)
    db.commit()
    db.refresh(db_category)
    return db_category

def update_category(db: Session, db_category: Category, category_update: CategoryUpdate) -> Category:
    update_data = category_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_category, field, value)
    db.commit()
    db.refresh(db_category)
    return db_category

def delete_category(db: Session, category_id: str) -> bool:
    db_category = get_category(db, category_id)
    if not db_category:
        return False
    db.delete(db_category)
    db.commit()
    return True
