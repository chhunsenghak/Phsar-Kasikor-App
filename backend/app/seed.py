import logging
from datetime import date, datetime, timezone
from app.core.database import SessionLocal
from app.models.user import User
from app.models.role import Role
from app.models.user_role import UserRole
from app.models.product import Product
from app.models.category import Category
from app.models.address_change_request import AddressChangeRequest
from app.models.crop_diagnosis import CropDiagnosis
from app.models.order import Order
from app.models.order_item import OrderItem
from app.models.contract import Contract, ContractItem
from app.models.dispute import Dispute
from app.models.content_report import ContentReport
from app.models.notification import Notification
from app.models.review import Review
from app.models.chat import ChatMessage
from app.models.cooperative import Cooperative, CooperativeMember
from app.models.market_price import MarketPrice
from app.models.forum import ForumPost, ForumComment
from app.models.saved_crop import SavedCrop
from app.models.delivery import Delivery
from app.models.farmer_certificate import FarmerCertificate
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

# Extra demo farmers/buyers, seeded only for the rich demo-content pass below
# (products/orders/contracts/etc.) — kept separate from USERS_TO_SEED so the
# always-on account list above stays untouched. Each carries a real address
# (province/district/commune/village codes from the Cambodia gazetteer,
# app/static/cambodia_gazetteer.json) since UserCreate/create_user turns
# these straight into an APPROVED AddressChangeRequest + user.address_id.
DEMO_USERS_TO_SEED = [
    {
        "email": "sok.pisey.farmer@phsarkasikor.demo",
        "username": "Sok Pisey",
        "phoneNumber": "+85512340001",
        "role_id": 3,
        "is_active": True,
        "is_verified": True,
        "password": "password123",
        "province": "02",
        "district": "000201",
        "commune": "20101",
        "village": "02010101",
        "street_address": "Phum Thmei",
        "latitude": 13.0957,
        "longitude": 103.2022,
    },
    {
        "email": "ly.vantha.farmer@phsarkasikor.demo",
        "username": "Ly Vantha",
        "phoneNumber": "+85512340002",
        "role_id": 3,
        "is_active": True,
        "is_verified": True,
        "password": "password123",
        "province": "03",
        "district": "000301",
        "commune": "30101",
        "village": "03010101",
        "street_address": "Phum Svay Pok",
        "latitude": 11.9944,
        "longitude": 105.4635,
    },
    {
        "email": "kong.sopha.buyer@phsarkasikor.demo",
        "username": "Kong Sopha",
        "phoneNumber": "+85512340003",
        "role_id": 4,
        "is_active": True,
        "is_verified": True,
        "password": "password123",
        "province": "04",
        "district": "000401",
        "commune": "40101",
        "village": "04010101",
        "street_address": "Phum Anhchanh Rung",
        "latitude": 12.2500,
        "longitude": 104.6667,
    },
    {
        "email": "meas.ratana.buyer@phsarkasikor.demo",
        "username": "Meas Ratana",
        "phoneNumber": "+85512340004",
        "role_id": 4,
        "is_active": True,
        "is_verified": True,
        "password": "password123",
        "province": "05",
        "district": "000501",
        "commune": "50101",
        "village": "05010101",
        "street_address": "Phum Prey Chheu Teal",
        "latitude": 11.4500,
        "longitude": 104.5167,
    },
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

# Fixed category IDs — must match CATEGORIES_TO_SEED inside seed_database().
GRAINS_CATEGORY_ID = "c8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf"
VEGETABLES_CATEGORY_ID = "v8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf"
FRUITS_CATEGORY_ID = "f8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf"

def _utc(y, m, d, hh=9, mm=0):
    return datetime(y, m, d, hh, mm, tzinfo=timezone.utc)

# ==============================================================================
# RICH DEMO CONTENT — products/orders/contracts/disputes/reviews/chat/etc.
# so every screen has real content to screenshot. Guarded by a marker check
# (see seed_demo_content) so re-running seed_database() doesn't duplicate it.
# ==============================================================================

def seed_demo_content(db):
    # Idempotency marker — if this already exists, the whole pass already ran.
    if db.query(Product).filter(Product.product_name == "White Rice").first():
        logger.info("Rich demo content already seeded — skipping.")
        return

    logger.info("Seeding rich demo content (products, orders, contracts, etc.)...")

    # --- Extra demo users ---
    for user_data in DEMO_USERS_TO_SEED:
        existing = db.query(User).filter(
            (User.email == user_data["email"]) | (User.phoneNumber == user_data["phoneNumber"])
        ).first()
        if not existing:
            user_service.create_user(db, user_in=UserCreate(**user_data))
            logger.info(f"Created demo user: {user_data['email']}")

    def get_user(email):
        return db.query(User).filter(User.email == email).first()

    farmer1 = get_user("chhun.senghak.web@gmail.com")   # Heng visal — pre-existing
    farmer2 = get_user("sok.pisey.farmer@phsarkasikor.demo")
    farmer3 = get_user("ly.vantha.farmer@phsarkasikor.demo")
    buyer1 = get_user("senghakchhun34@gmail.com")        # MonyMey — pre-existing
    buyer2 = get_user("kong.sopha.buyer@phsarkasikor.demo")
    buyer3 = get_user("meas.ratana.buyer@phsarkasikor.demo")
    admin = get_user("phsarkasikorapp.noreply@gmail.com")
    coop_leader = get_user("cooperative@association.com")

    # farmer1's address was created blank by an earlier manual profile edit
    # (no coordinates/street) — fill it in now that we're populating the map.
    if farmer1.address and farmer1.address.latitude is None:
        farmer1.address.latitude = 13.5859
        farmer1.address.longitude = 102.9759
        if not farmer1.address.street_address:
            farmer1.address.street_address = "Phum Ou Thum"
        db.commit()

    # --- Products ---
    # (seller, name, category_id, price, currency, qty, unit_type, weight_kg, image keyword, lock)
    products_to_create = [
        (farmer1, "Jasmine Rice", GRAINS_CATEGORY_ID, 1.20, "USD", 500, "KG", 1.0, "rice", 11),
        (farmer1, "Green Cabbage", VEGETABLES_CATEGORY_ID, 2500, "KHR", 300, "KG", 1.0, "cabbage", 12),
        (farmer2, "White Rice", GRAINS_CATEGORY_ID, 1.10, "USD", 800, "KG", 1.0, "rice", 13),
        (farmer2, "Cucumber", VEGETABLES_CATEGORY_ID, 1500, "KHR", 250, "KG", 1.0, "cucumber", 14),
        (farmer2, "Banana", FRUITS_CATEGORY_ID, 0.80, "USD", 400, "KG", 1.0, "banana", 15),
        (farmer2, "Long Bean", VEGETABLES_CATEGORY_ID, 3000, "KHR", 150, "KG", 1.0, "greenbeans", 16),
        (farmer3, "Yellow Corn", GRAINS_CATEGORY_ID, 0.90, "USD", 600, "KG", 1.0, "corn", 17),
        (farmer3, "Tomato", VEGETABLES_CATEGORY_ID, 2000, "KHR", 350, "KG", 1.0, "tomato", 18),
        (farmer3, "Durian", FRUITS_CATEGORY_ID, 8.00, "USD", 100, "KG", 1.0, "durian", 19),
        (farmer3, "Watermelon", FRUITS_CATEGORY_ID, 1200, "KHR", 200, "KG", 2.0, "watermelon", 20),
    ]
    products = {}
    for seller, name, cat_id, price, currency, qty, unit, weight, keyword, lock in products_to_create:
        p = Product(
            seller_id=seller.id,
            product_name=name,
            category_id=cat_id,
            price_per_unit=price,
            unit_type=unit,
            currency=currency,
            quantity_available=qty,
            weight_kg_per_unit=weight,
            harvest_date=date(2026, 9, 12),
            quality_certification_metadata=f"Fresh {name}, grown locally using good agricultural practices.",
            image_url=f"https://loremflickr.com/600/400/{keyword}?lock={lock}",
        )
        db.add(p)
        db.flush()
        products[name] = p
    db.commit()
    logger.info(f"Created {len(products)} demo products.")

    # Pre-existing products (created earlier through the live app, not this
    # script) — pulled in by name so orders/reviews/bookmarks below can
    # reference real farmer1 listings too.
    orange = db.query(Product).filter(Product.product_name == "ផ្លែក្រូច").first()
    mango = db.query(Product).filter(Product.product_name == "ផ្លៃស្វាយ").first()

    # --- Orders (+ items, + deliveries for DELIVERY-method orders) ---
    def make_order(buyer, seller, product, qty, currency, order_status, payment_status,
                    payment_method, delivery_method, created_at, delivery_fee=0.0,
                    delivery_status=None, contact_phone=None, current_lat=None, current_lng=None):
        subtotal = float(product.price_per_unit) * qty
        order = Order(
            buyer_id=buyer.id,
            seller_id=seller.id,
            total_amount=subtotal + delivery_fee,
            currency=currency,
            payment_status=payment_status,
            order_status=order_status,
            payment_method=payment_method,
            delivery_method=delivery_method,
            delivery_fee=delivery_fee,
            delivery_address_text=f"{buyer.username}'s pickup point" if delivery_method == "DELIVERY" else None,
            delivery_weight_kg=qty * float(product.weight_kg_per_unit or 1.0),
            created_at=created_at,
        )
        db.add(order)
        db.flush()
        db.add(OrderItem(order_id=order.id, product_id=product.id, quantity=qty, subtotal=subtotal))
        if delivery_method == "DELIVERY":
            db.add(Delivery(
                order_id=order.id,
                delivery_status=delivery_status or "pending",
                contact_phone=contact_phone,
                current_location_lat=current_lat,
                current_location_lng=current_lng,
            ))
        db.commit()
        return order

    orders = {}
    orders["A"] = make_order(buyer2, farmer2, products["White Rice"], 50, "USD",
                              "CONFIRMED", "PAID", "KHQR", "DELIVERY", _utc(2026, 5, 10),
                              delivery_fee=3.0, delivery_status="pending")
    orders["B"] = make_order(buyer2, farmer2, products["Banana"], 30, "USD",
                              "SHIPPED", "PAID", "KHQR", "DELIVERY", _utc(2026, 6, 15),
                              delivery_fee=2.5, delivery_status="in_transit",
                              contact_phone="+85512340001", current_lat=13.05, current_lng=103.15)
    orders["C"] = make_order(buyer3, farmer3, products["Durian"], 10, "USD",
                              "DELIVERED", "PAID", "KHQR", "PICKUP", _utc(2026, 6, 20))
    orders["D"] = make_order(buyer3, farmer3, products["Tomato"], 40, "KHR",
                              "DELIVERED", "PAID", "COD", "DELIVERY", _utc(2026, 7, 5),
                              delivery_fee=8000, delivery_status="arrived", contact_phone="+85512340002")
    orders["E"] = make_order(buyer1, farmer2, products["Cucumber"], 20, "KHR",
                              "CANCELLED", "PENDING", "KHQR", "PICKUP", _utc(2026, 7, 10))
    orders["F"] = make_order(buyer2, farmer3, products["Yellow Corn"], 100, "USD",
                              "PLACED", "PENDING", "KHQR", "DELIVERY", _utc(2026, 8, 1),
                              delivery_fee=5.0, delivery_status="pending")
    orders["G"] = make_order(buyer1, farmer1, products["Jasmine Rice"], 25, "USD",
                              "DELIVERED", "PAID", "KHQR", "DELIVERY", _utc(2026, 5, 25),
                              delivery_fee=2.0, delivery_status="arrived", contact_phone="+85512223333")
    if orange:
        orders["H"] = make_order(buyer3, farmer1, orange, 15, "KHR",
                                  "DELIVERED", "PAID", "KHQR", "DELIVERY", _utc(2026, 7, 20),
                                  delivery_fee=6000, delivery_status="arrived", contact_phone="+85512223333")
    if mango:
        orders["I"] = make_order(buyer2, farmer1, mango, 20, "KHR",
                                  "DELIVERED", "PAID", "KHQR", "DELIVERY", _utc(2026, 4, 15),
                                  delivery_fee=5000, delivery_status="arrived", contact_phone="+85512223333")
    orders["J"] = make_order(buyer1, farmer2, products["White Rice"], 30, "USD",
                              "DELIVERED", "REFUNDED", "KHQR", "DELIVERY", _utc(2026, 6, 1),
                              delivery_fee=3.0, delivery_status="arrived")
    logger.info(f"Created {len(orders)} demo orders.")

    # --- Contracts (+ items) ---
    def make_contract(buyer, seller, product, qty, unit_type, contract_status, start, end, **kw):
        contract = Contract(
            seller_id=seller.id,
            buyer_id=buyer.id,
            terms_description=kw.pop("terms", f"Wholesale supply agreement for {product.product_name}."),
            start_date=start,
            end_date=end,
            contract_status=contract_status,
            **kw,
        )
        db.add(contract)
        db.flush()
        db.add(ContractItem(
            contract_id=contract.id, product_id=product.id,
            agreed_price=float(product.price_per_unit), agreed_quantity=qty, unit_type=unit_type,
        ))
        db.commit()
        return contract

    contracts = {}
    contracts["draft"] = make_contract(
        buyer2, farmer2, products["White Rice"], 200, "KG", "DRAFT",
        _utc(2026, 9, 1), _utc(2026, 12, 1),
    )
    contracts["active"] = make_contract(
        buyer3, farmer3, products["Durian"], 50, "KG", "ACTIVE",
        _utc(2026, 8, 1), _utc(2026, 11, 1),
        deposit_percentage=20.0, deposit_amount=800.0, deposit_status="PAID", deposit_currency="USD",
    )
    contracts["pending_final"] = make_contract(
        buyer1, farmer2, products["Banana"], 100, "KG", "PENDING_FINAL_PAYMENT",
        _utc(2026, 7, 1), _utc(2026, 10, 1),
        deposit_percentage=20.0, deposit_amount=16.0, deposit_status="PAID", deposit_currency="USD",
        delivery_method="DELIVERY", delivery_fee=10.0, final_amount=74.0, final_payment_status="PENDING",
    )
    contracts["in_fulfillment"] = make_contract(
        buyer2, farmer3, products["Yellow Corn"], 100, "KG", "IN_FULFILLMENT",
        _utc(2026, 7, 15), _utc(2026, 10, 15),
        deposit_percentage=20.0, deposit_amount=18.0, deposit_status="PAID", deposit_currency="USD",
        delivery_method="DELIVERY", delivery_fee=5.0, final_amount=77.0, final_payment_status="PAID",
        fulfillment_order_id=orders["F"].id,
    )
    contracts["completed"] = make_contract(
        buyer3, farmer3, products["Durian"], 10, "KG", "COMPLETED",
        _utc(2026, 5, 1), _utc(2026, 7, 1),
        deposit_percentage=20.0, deposit_amount=16.0, deposit_status="PAID", deposit_currency="USD",
        delivery_method="PICKUP", delivery_fee=0.0, final_amount=64.0, final_payment_status="PAID",
        fulfillment_order_id=orders["C"].id,
    )
    contracts["terminated"] = make_contract(
        buyer1, farmer3, products["Tomato"], 60, "KG", "TERMINATED",
        _utc(2026, 6, 1), _utc(2026, 8, 1),
        deposit_status="PENDING",
        terms="Seller withdrew before deposit was paid.",
    )
    logger.info(f"Created {len(contracts)} demo contracts (plus the pre-existing one).")

    # --- Reviews (one per DELIVERED order, at most once per order) ---
    def make_review(order, rating, comment):
        if not order or db.query(Review).filter(Review.order_id == order.id).first():
            return
        first_item = order.items[0] if order.items else None
        db.add(Review(
            order_id=order.id,
            reviewer_id=order.buyer_id,
            reviewee_id=order.seller_id,
            product_id=first_item.product_id if first_item else None,
            rating=rating,
            comment=comment,
            created_at=order.created_at,
        ))
        # Flush immediately so the uq_review_order dedup check above sees
        # this row on the very next make_review call within the same
        # transaction — a plain db.add() alone isn't visible to a query
        # until it's flushed.
        db.flush()

    make_review(orders["C"], 5, "Excellent durian, very fresh and sweet! Will order again.")
    make_review(orders["D"], 3, "Good tomatoes but delivery took a bit longer than expected.")
    make_review(orders["G"], 5, "Great quality rice, nicely packaged.")
    make_review(orders.get("I"), 4, "Sweet mangoes, good packaging.")
    make_review(orders["J"], 2, "Had an issue with this order — resolved by admin after a dispute.")
    for existing_order in db.query(Order).filter(
        Order.buyer_id == buyer1.id, Order.seller_id == farmer1.id, Order.order_status == "DELIVERED"
    ).all():
        make_review(existing_order, 5, "Reliable seller, consistently fresh produce.")
    db.commit()

    # --- Disputes ---
    if orders.get("H") and not db.query(Dispute).filter(Dispute.order_id == orders["H"].id).first():
        db.add(Dispute(
            order_id=orders["H"].id,
            raised_by=buyer3.id,
            reason="Received fewer oranges than what was ordered.",
            status="OPEN",
            created_at=_utc(2026, 7, 21),
        ))
    if not db.query(Dispute).filter(Dispute.order_id == orders["J"].id).first():
        db.add(Dispute(
            order_id=orders["J"].id,
            raised_by=buyer1.id,
            reason="Rice bags arrived damaged and partially spilled.",
            status="RESOLVED_REFUND",
            resolution_note="Refund approved after reviewing the buyer's photos.",
            refund_amount=float(orders["J"].total_amount),
            created_at=_utc(2026, 6, 2),
            resolved_at=_utc(2026, 6, 5),
        ))
    db.commit()
    logger.info("Created demo disputes.")

    # --- Content reports (moderation queue) ---
    if orange and not db.query(ContentReport).filter(
        ContentReport.product_id == orange.id, ContentReport.reporter_id == buyer3.id
    ).first():
        db.add(ContentReport(
            reporter_id=buyer3.id, product_id=orange.id,
            reason="Suspected mislabeled organic claim on this listing.",
            status="resolved", admin_feedback="Verified certification — listing is compliant.",
            created_at=_utc(2026, 7, 15), reviewed_at=_utc(2026, 7, 16),
        ))
    db.add(ContentReport(
        reporter_id=buyer2.id, product_id=products["Tomato"].id,
        reason="Listing price seems much higher than the current market rate.",
        status="pending", created_at=_utc(2026, 8, 10),
    ))
    db.commit()
    logger.info("Created demo content reports.")

    # --- Cooperative + members ---
    coop = db.query(Cooperative).filter(Cooperative.leader_id == coop_leader.id).first()
    if not coop:
        coop = Cooperative(
            leader_id=coop_leader.id,
            name="Banteay Meanchey Farmers Cooperative",
            province="01",
            description="A cooperative supporting smallholder rice and produce farmers across Banteay Meanchey.",
        )
        db.add(coop)
        db.flush()
    for farmer, status in [(farmer1, "active"), (farmer2, "pending"), (farmer3, "active")]:
        if not db.query(CooperativeMember).filter(
            CooperativeMember.cooperative_id == coop.id, CooperativeMember.farmer_id == farmer.id
        ).first():
            db.add(CooperativeMember(cooperative_id=coop.id, farmer_id=farmer.id, status=status))
    db.commit()
    logger.info("Created demo cooperative + members.")

    # --- Market prices ---
    # All in USD/kg — MarketPrice has no currency column, and
    # market_price_tracker.dart (frontend) always renders a literal "$"
    # prefix regardless of what's stored, so a KHR-scale number here would
    # display as a nonsensical dollar amount (e.g. "$5000.00/kg" for oranges).
    market_prices_to_seed = [
        ("Rice (Jasmine)", 1.20, 1.35, 1.05, "Phnom Penh Central Market", date(2026, 8, 10)),
        ("Mango", 0.12, 0.15, 0.10, "Battambang Provincial Market", date(2026, 8, 11)),
        ("Orange", 1.25, 1.35, 1.10, "Phnom Penh Central Market", date(2026, 8, 11)),
        ("Corn (Yellow)", 0.90, 1.00, 0.75, "Kampong Cham Market", date(2026, 8, 12)),
        ("Durian", 8.00, 9.50, 7.00, "Kampong Cham Market", date(2026, 8, 12)),
        ("Watermelon", 0.30, 0.35, 0.25, "Battambang Provincial Market", date(2026, 8, 13)),
        ("Cabbage", 0.60, 0.68, 0.55, "Phnom Penh Central Market", date(2026, 8, 13)),
    ]
    for commodity, avg, high, low, location, recorded in market_prices_to_seed:
        if not db.query(MarketPrice).filter(
            MarketPrice.commodity_name == commodity, MarketPrice.recorded_date == recorded
        ).first():
            db.add(MarketPrice(
                commodity_name=commodity, average_market_price=avg,
                highest_price=high, lowest_price=low,
                market_location=location, recorded_date=recorded,
            ))
    db.commit()
    logger.info("Created demo market prices.")

    # --- Forum posts + comments ---
    forum_posts_to_seed = [
        (farmer1, "Pest Control", "How to deal with rice blast this season?",
         "My jasmine rice field started showing gray-centered lesions on the leaves after the last heavy rain. "
         "Has anyone had success treating this early before it spreads to the panicles?", 5,
         [(buyer1, "Try a copper-based fungicide — it's mentioned in the Crop Advisor's reference list too."),
          (farmer3, "I had the same last year — improving drainage between rows helped a lot.")]),
        (farmer2, "Market Prices", "Rice prices rising in Battambang market this week",
         "Noticed jasmine rice prices climbing about 10% at the provincial market compared to last month. "
         "Good time to sell if you're holding stock.", 3,
         [(buyer2, "Thanks for the heads up!"),
          (farmer3, "Seeing a similar trend here in Kampong Cham.")]),
        (farmer3, "Organic Farming", "Tips for getting organic/GI certification for durian",
         "Just got my durian certified — happy to share what documentation the inspectors actually asked for "
         "if anyone else is applying this season.", 8,
         [(farmer1, "Congrats on going organic! Would love to hear more."),
          (admin, "Great initiative — reach out to the admin team if you need guidance on the process.")]),
        (buyer1, "General", "Looking for reliable rice suppliers near Phnom Penh",
         "Buying regularly for a small restaurant — looking for farmers who can commit to weekly deliveries.", 2,
         [(farmer1, "I can supply consistently — sent you a message!"),
          (farmer2, "Same here, check my rice listing for pricing.")]),
    ]
    for author, category, title, content, likes, comments in forum_posts_to_seed:
        post = db.query(ForumPost).filter(ForumPost.title == title).first()
        if not post:
            post = ForumPost(author_id=author.id, category=category, title=title, content=content, likes_count=likes)
            db.add(post)
            db.flush()
            for comment_author, comment_text in comments:
                db.add(ForumComment(post_id=post.id, author_id=comment_author.id, content=comment_text))
    db.commit()
    logger.info("Created demo forum posts + comments.")

    # A pending report against the last forum post, so the moderation queue
    # covers both product and post reports.
    last_post = db.query(ForumPost).filter(ForumPost.title == forum_posts_to_seed[-1][2]).first()
    if last_post and not db.query(ContentReport).filter(ContentReport.post_id == last_post.id).first():
        db.add(ContentReport(
            reporter_id=farmer2.id, post_id=last_post.id,
            reason="This reads like a promotional post rather than a genuine question.",
            status="pending", created_at=_utc(2026, 8, 12),
        ))
        db.commit()

    # --- Chat messages ---
    def make_conversation(user_a, user_b, exchange, unread_last=False):
        if db.query(ChatMessage).filter(
            ((ChatMessage.sender_id == user_a.id) & (ChatMessage.receiver_id == user_b.id)) |
            ((ChatMessage.sender_id == user_b.id) & (ChatMessage.receiver_id == user_a.id))
        ).first():
            return
        base = _utc(2026, 8, 12, 14, 0)
        for i, (sender, text) in enumerate(exchange):
            receiver = user_b if sender is user_a else user_a
            is_last = i == len(exchange) - 1
            db.add(ChatMessage(
                sender_id=sender.id, receiver_id=receiver.id, message_text=text,
                is_read=not (is_last and unread_last),
                created_at=_utc(base.year, base.month, base.day, base.hour, min(59, base.minute + i * 3)),
            ))
        db.commit()

    make_conversation(buyer2, farmer2, [
        (buyer2, "Hi, do you still have white rice in stock this week?"),
        (farmer2, "Yes! Just harvested, 800kg available."),
        (buyer2, "Great, I'd like to order 50kg for delivery."),
        (farmer2, "Sure, I'll get that ready — confirming your order now."),
    ], unread_last=False)
    make_conversation(buyer3, farmer3, [
        (buyer3, "Hello, is your durian ready for pickup yet?"),
        (farmer3, "Almost — should be ready in 2 days, very sweet this batch."),
        (buyer3, "Perfect, I'll come by Thursday then."),
    ], unread_last=True)
    make_conversation(buyer1, farmer2, [
        (buyer1, "Hi, I saw your banana listing — still available?"),
        (farmer2, "Yes, 400kg in stock right now."),
    ], unread_last=True)
    logger.info("Created demo chat conversations.")

    # --- Notifications ---
    notifications_to_seed = [
        (farmer1, "Order Delivered", "Your order for Jasmine Rice has been delivered.", True),
        (farmer1, "Certificate Approved", "Your organic certificate has been approved.", False),
        (farmer2, "Cooperative Invitation", "Banteay Meanchey Farmers Cooperative invited you to join.", False),
        (farmer3, "New Order Received", "You have a new order for Yellow Corn awaiting payment.", False),
        (buyer1, "Dispute Resolved", "Your dispute on order #J has been resolved with a refund.", True),
        (buyer1, "Leave a Review", "How was your Jasmine Rice order? Leave a review for the seller.", False),
        (buyer2, "Order Shipped", "Your banana order is on its way.", False),
        (buyer3, "Order Confirmed", "Your durian order has been confirmed by the seller.", True),
        (admin, "New Dispute Opened", "A new dispute was raised on a recent order.", False),
        (admin, "Certificate Pending Review", "A new farmer certificate is awaiting your review.", False),
    ]
    for user, title, message, is_read in notifications_to_seed:
        db.add(Notification(user_id=user.id, title=title, message=message, is_read=is_read))
    db.commit()
    logger.info("Created demo notifications.")

    # --- Saved crops (bookmarks) ---
    saved_crops_to_seed = [
        (buyer1, orange), (buyer1, products.get("White Rice")),
        (buyer2, products.get("Durian")),
        (buyer3, products.get("Jasmine Rice")), (buyer3, products.get("Cucumber")),
    ]
    for user, product in saved_crops_to_seed:
        if product and not db.query(SavedCrop).filter(
            SavedCrop.user_id == user.id, SavedCrop.product_id == product.id
        ).first():
            db.add(SavedCrop(user_id=user.id, product_id=product.id))
    db.commit()
    logger.info("Created demo bookmarks.")

    # --- Farmer certificates (beyond the one already approved for farmer1) ---
    if not db.query(FarmerCertificate).filter(FarmerCertificate.user_id == farmer2.id).first():
        db.add(FarmerCertificate(
            user_id=farmer2.id, certificate_type="gap",
            issuing_body="Provincial Department of Agriculture",
            document_url="https://loremflickr.com/600/400/certificate?lock=31",
            status="pending", created_at=_utc(2026, 8, 5),
        ))
    if not db.query(FarmerCertificate).filter(FarmerCertificate.user_id == farmer3.id).first():
        db.add(FarmerCertificate(
            user_id=farmer3.id, certificate_type="gi",
            issuing_body="Ministry of Commerce",
            document_url="https://loremflickr.com/600/400/certificate?lock=32",
            status="approved", admin_feedback="Approved — documentation verified.",
            created_at=_utc(2026, 7, 1), reviewed_at=_utc(2026, 7, 3),
        ))
    db.commit()
    logger.info("Created demo farmer certificates.")

    # --- One pending address-change request, for the admin review queue ---
    if not db.query(AddressChangeRequest).filter(
        AddressChangeRequest.user_id == buyer1.id, AddressChangeRequest.status == "PENDING"
    ).first():
        db.add(AddressChangeRequest(
            user_id=buyer1.id, status="PENDING",
            province="01", district="000102", commune="10201", village="01020102",
            street_address="New street address near the market",
            latitude=13.58, longitude=102.97,
            created_at=_utc(2026, 8, 11),
        ))
        db.commit()
    logger.info("Created demo pending address request.")

    logger.info("Rich demo content seeding completed.")

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

        # 3. Seed rich demo content (products, orders, contracts, disputes,
        # reviews, chat, notifications, cooperative, market prices, forum,
        # bookmarks, certificates) so every screen has real content.
        seed_demo_content(db)

        logger.info("Database seeding completed successfully.")

    except Exception as e:
        logger.error(f"Error seeding database: {e}")
        raise e
    finally:
        db.close()

if __name__ == "__main__":
    seed_database()
