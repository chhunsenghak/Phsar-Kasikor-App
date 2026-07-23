import logging
from app.core.database import SessionLocal
from app.models.user import User
from app.models.role import Role
from app.models.user_role import UserRole
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
    "MERCHANT": "Merchant/Agribusiness buyer sourcing products",
    "TECHNICIAN": "Agricultural technician providing advice and checks",
    "BUYER": "Standard crop buyer on the marketplace platform"
}

# Default Users definitions (Representative accounts for development testing)
USERS_TO_SEED = [
    {
        "email": "admin@phsarkasikor.com",
        "username": "admin",
        "phoneNumber": "+85511112222",
        "role_id": 1,
        "province": "Phnom Penh",
        "district": "Chamkar Mon",
        "commune": "Tonle Bassac",
        "village": "Village 3",
        "street_address": "Street 308, House 4B",
        "password": "adminpassword123"
    },
    {
        "email": "farmer@phsarkasikor.com",
        "username": "sok_farmer",
        "phoneNumber": "+85512223333",
        "role_id": 3,
        "province": "Battambang",
        "district": "Sangkae",
        "commune": "Wat Ta Mim",
        "village": "O Sralau",
        "street_address": "Street 105",
        "password": "farmerpassword123"
    },
    {
        "email": "buyer@phsarkasikor.com",
        "username": "chavy_buyer",
        "phoneNumber": "+85588889999",
        "role_id": 6,
        "province": "Siem Reap",
        "district": "Krong Siem Reap",
        "commune": "Slor Kram",
        "village": "Mondul 3",
        "street_address": "Road 6",
        "password": "buyerpassword123"
    },
    {
        "email": "technician@phsarkasikor.com",
        "username": "dara_technician",
        "phoneNumber": "+85577778888",
        "role_id": 5,
        "province": "Kandal",
        "district": "Ta Khmau",
        "commune": "Ta Khmau",
        "village": "Prek Samraong",
        "street_address": "Road 21",
        "password": "techpassword123"
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
                logger.info(f"User with email '{email}' or phone '{phone}' already exists.")

        logger.info("Database seeding completed successfully.")

    except Exception as e:
        logger.error(f"Error seeding database: {e}")
        raise e
    finally:
        db.close()

if __name__ == "__main__":
    seed_database()
