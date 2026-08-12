import logging
from app.core.database import SessionLocal
from app.models.user import User
from app.models.role import Role
from app.models.user_role import UserRole
from app.models.product import Product
from app.models.category import Category
from app.models.address_change_request import AddressChangeRequest
from app.models.crop_diagnosis import CropDiagnosis
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

# Crop Diagnosis reference data — keywords are matched case-insensitively
# as substrings against a farmer's free-text symptom description (see
# crop_diagnosis_service.match_symptoms).
CROP_DIAGNOSES_TO_SEED = [
    {
        "disease_name": "Rice Blast",
        "disease_name_kh": "ជំងឺរបំផ្ទុះស្លឹកស្រូវ",
        "crop_type": "Rice",
        "keywords": "rice, leaf, spot, blast, lesion, gray, diamond",
        "symptoms_description": "Diamond-shaped, gray-centered lesions with brown borders on leaves; can also affect stems and panicles, causing them to break.",
        "symptoms_description_kh": "ស្នាមរាងពេជ្រពណ៌ប្រផេះនៅកណ្តាល និងគែមពណ៌ត្នោតនៅលើស្លឹក អាចរាលដាលដល់ដើម និងកួរស្រូវធ្វើឱ្យបាក់។",
        "treatment_advice": "Apply a copper-based or triazole fungicide, reduce nitrogen fertilizer, and improve field drainage and airflow between plants.",
        "treatment_advice_kh": "បាញ់ថ្នាំកម្ចាត់ផ្សិតមានផ្ទុកទង់ដែង ឬប្រភេទ triazole កាត់បន្ថយជីអាសូត និងធ្វើឱ្យស្រែមានលំហូរខ្យល់ និងលូទឹកបានល្អ។",
    },
    {
        "disease_name": "Rice Bacterial Leaf Blight",
        "disease_name_kh": "ជំងឺរបំផ្ទុះស្លឹកបាក់តេរីស្រូវ",
        "crop_type": "Rice",
        "keywords": "rice, yellow, wilt, blight, water-soaked, stripe",
        "symptoms_description": "Water-soaked stripes on leaf edges that turn yellow to white and dry out; whole leaves may wilt in severe cases.",
        "symptoms_description_kh": "ខ្សែស្នាមទឹកជោគនៅគែមស្លឹកប្រែជាពណ៌លឿងទៅសដិត ស្លឹកអាចក្រៀមក្នុងករណីធ្ងន់ធ្ងរ។",
        "treatment_advice": "Use resistant rice varieties, avoid excess nitrogen, drain and dry the field periodically, and remove and destroy infected plant debris.",
        "treatment_advice_kh": "ប្រើពូជស្រូវធន់នឹងជំងឺ ជៀសវាងជីអាសូតច្រើនពេក បង្ហូរ និងសម្ងួតស្រែម្តងម្កាល ដកចេញ និងបំផ្លាញសំណល់រុក្ខជាតិដែលឆ្លង។",
    },
    {
        "disease_name": "Citrus Canker",
        "disease_name_kh": "ជំងឺដុះដំបៅសំបកក្រូច",
        "crop_type": "Citrus",
        "keywords": "citrus, orange, lemon, canker, lesion, corky, fruit",
        "symptoms_description": "Raised, corky, brown lesions with a yellow halo on leaves, stems, and fruit.",
        "symptoms_description_kh": "ដំបៅពណ៌ត្នោតរឹង មានរង្វង់លឿងព័ទ្ធជុំវិញនៅលើស្លឹក មែក និងផ្លែ។",
        "treatment_advice": "Prune and destroy infected branches, apply a copper-based spray, disinfect tools between trees, and avoid overhead irrigation.",
        "treatment_advice_kh": "កាត់ និងបំផ្លាញមែកឆ្លង បាញ់ថ្នាំមានផ្ទុកទង់ដែង សម្អាតឧបករណ៍រវាងដើមនីមួយៗ ជៀសវាងស្រោចទឹកពីលើ។",
    },
    {
        "disease_name": "Citrus Greening (Huanglongbing)",
        "disease_name_kh": "ជំងឺក្រូចលឿងស្លឹកបៃតង",
        "crop_type": "Citrus",
        "keywords": "citrus, orange, greening, yellow, mottled, bitter, small fruit",
        "symptoms_description": "Blotchy, asymmetric yellow mottling on leaves, small lopsided bitter fruit, and twig dieback.",
        "symptoms_description_kh": "ស្នាមប្រផេះលឿងមិនស៊ីមេទ្រីនៅលើស្លឹក ផ្លែតូច មិនស្មើគ្នា និងជូរល្វីង មែកងាប់បន្តិចម្តង។",
        "treatment_advice": "Remove and destroy infected trees promptly, control the Asian citrus psyllid with an approved insecticide, and plant certified disease-free stock.",
        "treatment_advice_kh": "ដកចេញ និងបំផ្លាញដើមឆ្លងភ្លាមៗ កម្ចាត់សត្វល្អិត Asian citrus psyllid ដោយថ្នាំសម្លាប់សត្វល្អិត ដាំដោយប្រើដើមកូនឈើគ្មានជំងឺដែលបានទទួលស្គាល់។",
    },
    {
        "disease_name": "Cassava Mosaic Disease",
        "disease_name_kh": "ជំងឺម៉ូសាអ៊ិកដំឡូងមី",
        "crop_type": "Cassava",
        "keywords": "cassava, mosaic, chlorosis, distorted, stunted, yellow",
        "symptoms_description": "Yellow-green mosaic patterning and distortion on leaves, stunted plant growth, and reduced tuber yield.",
        "symptoms_description_kh": "ស្នាមលាយពណ៌លឿង-បៃតងខូចទ្រង់ទ្រាយនៅលើស្លឹក ដើមរីកយឺត និងទិន្នផលកិនថយចុះ។",
        "treatment_advice": "Plant certified virus-free cuttings, remove and destroy infected plants, and control whitefly vectors.",
        "treatment_advice_kh": "ដាំកូនដំឡូងមីស្អាតគ្មានមេរោគ ដកចេញ និងបំផ្លាញដើមឆ្លង កម្ចាត់សត្វល្អិតសពៃដែលជាអ្នកចម្លង។",
    },
    {
        "disease_name": "Tomato Early Blight",
        "disease_name_kh": "ជំងឺរបំផ្ទុះដំណាប់ដំបូងប៉េងប៉ោះ",
        "crop_type": "Tomato",
        "keywords": "tomato, blight, brown spot, ring, yellow, leaf drop",
        "symptoms_description": "Dark brown spots with concentric rings on older leaves first, surrounded by yellowing; leaves eventually drop.",
        "symptoms_description_kh": "ស្នាមប្រផេះត្នោតងងឹតមានរង្វង់ជាបន្តបន្ទាប់នៅលើស្លឹកចាស់ជាមុន ព័ទ្ធជុំវិញដោយពណ៌លឿង ស្លឹកជ្រុះជាចុងក្រោយ។",
        "treatment_advice": "Remove infected lower leaves, apply a chlorothalonil or copper fungicide, rotate crops, and avoid overhead watering.",
        "treatment_advice_kh": "ដកចេញស្លឹកខាងក្រោមដែលឆ្លង បាញ់ថ្នាំកម្ចាត់ផ្សិត ដាំដំណាំបញ្ច្រាស គេចវេសពីការស្រោចទឹកពីលើ។",
    },
    {
        "disease_name": "Corn Leaf Spot",
        "disease_name_kh": "ជំងឺដុះស្នាមស្លឹកពោត",
        "crop_type": "Corn",
        "keywords": "corn, maize, leaf spot, lesion, tan, streak",
        "symptoms_description": "Small tan to gray oval lesions on leaves, sometimes with a dark border, that can merge and kill leaf tissue in humid weather.",
        "symptoms_description_kh": "ស្នាមរាងពងក្រពើពណ៌ត្នោតលឿងតូចៗនៅលើស្លឹក ជួនកាលមានគែមងងឹត អាចរួមគ្នា និងសម្លាប់ជាលិកាស្លឹកនៅពេលមានសំណើម។",
        "treatment_advice": "Rotate crops away from corn for a season, apply a foliar fungicide if severe, and choose resistant hybrid varieties next planting.",
        "treatment_advice_kh": "ដាំដំណាំបញ្ច្រាសពីពោតមួយរដូវ បាញ់ថ្នាំកម្ចាត់ផ្សិតប្រសិនបើធ្ងន់ធ្ងរ ជ្រើសរើសពូជធន់សម្រាប់ដាំលើកក្រោយ។",
    },
    {
        "disease_name": "General Nutrient or Soil Stress",
        "disease_name_kh": "ភាពតានតឹងជីជាតិ ឬដីទូទៅ",
        "crop_type": "General",
        "keywords": "yellow, wilt, stunted, weak, pale, slow growth, poor growth",
        "symptoms_description": "Pale or yellowing leaves, slow or stunted growth, and weak stems without the distinct lesions or patterns of a specific disease — often nutrient deficiency, poor drainage, or soil compaction rather than infection.",
        "symptoms_description_kh": "ស្លឹកលឿង ឬស្លេក រីកលូតលាស់យឺត ឬតូច និងដើមទន់ខ្សោយ ដោយគ្មានស្នាមឬលំនាំច្បាស់លាស់នៃជំងឺជាក់លាក់ណាមួយ ជាធម្មតាបណ្តាលមកពីកង្វះជីជាតិ ការបង្ហូរទឹកមិនល្អ ឬដីរឹង។",
        "treatment_advice": "Test soil pH and nutrients if possible, improve drainage, apply balanced compost or fertilizer, and avoid waterlogging and over-crowding.",
        "treatment_advice_kh": "ធ្វើតេស្តជីជាតិ និង pH ដីប្រសិនបើអាចធ្វើបាន កែលម្អការបង្ហូរទឹក ដាក់ជីកំប៉ុសឬជីស្មើគ្នា ជៀសវាងទឹកជោគ និងការដាំក្រាស់ពេក។",
    },
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

        # 1.6 Seed Crop Diagnosis reference data — backs the Crop Advisor's
        # real symptom-matching (see crop_diagnosis_service.match_symptoms)
        # and its "common issues" reference list, replacing what used to be
        # two hardcoded lists in the Flutter screen.
        for entry in CROP_DIAGNOSES_TO_SEED:
            db_diagnosis = db.query(CropDiagnosis).filter(
                CropDiagnosis.disease_name == entry["disease_name"]
            ).first()
            if not db_diagnosis:
                db.add(CropDiagnosis(**entry))
                db.commit()
                logger.info(f"Created crop diagnosis: {entry['disease_name']}")
            else:
                logger.info(f"Crop diagnosis {entry['disease_name']} already exists.")

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
                # "password" is the plain-text seed value, not a hash — only
                # meaningful on first create (create_user hashes it there).
                # Re-seeding an existing account must never touch its real
                # password, or every reseed silently resets it to garbage.
                update_data = {k: v for k, v in user_data.items() if k != "password"}
                user_service.update_user(db, db_obj=db_user, obj_in=update_data)
                logger.info(f"Updated user: {email}")

        logger.info("Database seeding completed successfully.")

    except Exception as e:
        logger.error(f"Error seeding database: {e}")
        raise e
    finally:
        db.close()

if __name__ == "__main__":
    seed_database()
