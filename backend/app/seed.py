import logging
from app.core.database import SessionLocal
from app.models.user import User
from app.models.role import Role
from app.models.user_role import UserRole
from app.models.product import Product
from app.models.category import Category
from app.models.address_change_request import AddressChangeRequest
from app.services import role_service, user_service
from app.schemas.user import UserCreate

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger("seeder")

# ==============================================================================
# SEED DATA CONFIGURATIONS
# ==============================================================================

# Default Roles definitions
ROLES_TO_SEED = {
    "ADMIN": "Administrator role with full backend control",
    "ASSOCIATION": "Association Agricultural group role representing local cooperatives",
    "FARMER": "Producer farmer producing crops and managing listings",
    "BUYER": "Standard crop buyer on the marketplace platform"
}

# Default Users definitions (Representative accounts for development testing)
USERS_TO_SEED = [
    {
        "email": "phsarkasikorapp.noreply@gmail.com",
        "username": "admin",
        "phoneNumber": "+85511112222",
        "role_id": 1,
        "is_active": True,
        "is_verified": True,
        "password": "password123"
    },
    {
        "email": "chhun.senghak.web@gmail.com",
        "username": "Chhun Farmer",
        "phoneNumber": "+85512223333",
        "role_id": 3,
        "is_active": True,
        "is_verified": True,
        "password": "password123"
    },
    {
        "email": "senghakchhun34@gmail.com",
        "username": "Chhun Buyer",
        "phoneNumber": "+85588889999",
        "role_id": 4,
        "is_active": True,
        "is_verified": True,
        "password": "password123"
    },
    {
        "email": "cooperative@association.com",
        "username": "Cooperative Association",
        "phoneNumber": "+85599990000",
        "role_id": 2,
        "is_active": True,
        "is_verified": True,
        "password": "password123"
    }
]

# ==============================================================================
# SEEDING EXECUTION LOGIC
# ==============================================================================

def seed_database():
    db = SessionLocal()
    try:
        logger.info("Starting database seeding...")

        # 1. Seed Roles
        for role_name, desc in ROLES_TO_SEED.items():
            db_role = role_service.get_role_by_name(db, name=role_name)
            if not db_role:
                role_service.create_role(db, name=role_name, description=desc)
                logger.info(f"Created role: {role_name}")
            else:
                logger.info(f"Role {role_name} already exists.")

        # 1.5 Seed Default Categories
        CATEGORIES_TO_SEED = {
            "c8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf": ("Grains", "Harvested grains, rice, and agricultural crops"),
            "v8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf": ("Vegetables", "Fresh vegetables, greens, and roots"),
            "f8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf": ("Fruits", "Fresh harvested local fruits"),
        }
        for cat_id, (cat_name, cat_desc) in CATEGORIES_TO_SEED.items():
            db_category = db.query(Category).filter(Category.id == cat_id).first()
            if not db_category:
                new_cat = Category(
                    id=cat_id,
                    name=cat_name,
                    description=cat_desc
                )
                db.add(new_cat)
                db.commit()
                logger.info(f"Created category: {cat_name}")
            else:
                logger.info(f"Category {cat_name} already exists.")

        # 2. Seed Users
        for user_data in USERS_TO_SEED:
            email = user_data["email"]
            phone = user_data["phoneNumber"]
            
            # Check by email OR phone number to avoid unique constraint violations
            db_user = db.query(User).filter(
                (User.email == email) | (User.phoneNumber == phone)
            ).first()
            
            if not db_user:
                user_in = UserCreate(**user_data)
                user_service.create_user(db, user_in=user_in)
                logger.info(f"Created user: {email} with role_id: {user_data['role_id']}")
            else:
                user_service.update_user(db, db_obj=db_user, obj_in=user_data)
                logger.info(f"Updated user: {email}")

        logger.info("Database seeding completed successfully.")

    except Exception as e:
        logger.error(f"Error seeding database: {e}")
        raise e
    finally:
        db.close()

if __name__ == "__main__":
    seed_database()
