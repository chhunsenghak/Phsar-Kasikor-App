from typing import List, Optional
from sqlalchemy.orm import Session, joinedload
from app.models.order import Order
from app.models.order_item import OrderItem
from app.models.product import Product
from app.models.user import User
from app.models.delivery import Delivery
from app.schemas.order import OrderCreate, OrderUpdate
from app.schemas.notification import NotificationCreate
from app.services import geo_service, khqr_service, notification_service

# Below this, a listing is "running low" — worth telling the farmer about
# before they oversell or a buyer hits an empty listing.
LOW_STOCK_THRESHOLD = 10

# A seller-driven pipeline — only the seller advances it (matches the
# existing app UX, where only the farmer's screen exposes these actions).
# CANCELLED is reached only via cancel_order, never via this map.
ORDER_STATUS_TRANSITIONS = {
    "PLACED": {"CONFIRMED"},
    "CONFIRMED": {"SHIPPED"},
    "SHIPPED": {"DELIVERED"},
}

# Weight assumed per unit when a farmer hasn't declared Product.weight_kg_per_unit
# — rough per-unit-type averages, used only as a fallback so pricing still
# works for older/unedited listings.
DEFAULT_WEIGHT_KG_PER_UNIT = {
    "KG": 1.0,
    "TON": 1000.0,
    "SACK": 50.0,
    "CRATE": 20.0,
    "BUNCH": 5.0,
    "BOX": 10.0,
    "PIECE": 1.0,
}

# Straight-line distance assumed when the seller hasn't set a profile
# location yet, so pricing still works instead of blocking checkout — a
# rough average trip within a Cambodian province.
DEFAULT_DISTANCE_KM = 15.0

# fee = base + per_km*distance + per_kg*weight, clamped to [min, max]. The
# only real "pricing" knobs in this module — tune here.
_DELIVERY_PRICING = {
    "USD": {"base": 1.0, "per_km": 0.05, "per_kg": 0.03, "min": 1.0, "max": 25.0},
    "KHR": {"base": 4000.0, "per_km": 200.0, "per_kg": 120.0, "min": 4000.0, "max": 100000.0},
}

def _delivery_fee_for(currency: str, distance_km: float, weight_kg: float) -> float:
    pricing = _DELIVERY_PRICING.get(currency, _DELIVERY_PRICING["USD"])
    fee = pricing["base"] + pricing["per_km"] * distance_km + pricing["per_kg"] * weight_kg
    fee = max(pricing["min"], min(pricing["max"], fee))
    # Riel has no practical fractional denomination in daily use, unlike
    # USD cents — round to the nearest 100.
    return round(fee / 100) * 100 if currency == "KHR" else round(fee, 2)

def verify_and_settle_khqr(db: Session, md5_hash: str) -> tuple[str, List[Order]]:
    """
    Re-checks the given KHQR against Bakong and, only on a confirmed "paid",
    flips every still-PENDING order linked to it. This is the single place
    payment_status ever becomes PAID off a KHQR scan — called both by the
    buyer's explicit "I've Paid" tap/poll and by the opportunistic re-check
    in get_order(), so payment tracking is automatic and never depends on
    the buyer, seller, or admin manually saying "yes it's paid".
    Returns ("paid", orders) / ("unpaid", []) / ("unavailable", []).
    """
    orders = db.query(Order).filter(
        Order.khqr_md5 == md5_hash,
        Order.payment_status == "PENDING",
        Order.order_status != "CANCELLED",
    ).all()
    if not orders:
        return ("unpaid", [])

    paid = khqr_service.check_payment_status(md5_hash)
    if paid is None:
        return ("unavailable", [])
    if paid is False:
        return ("unpaid", [])

    for o in orders:
        o.payment_status = "PAID"
    db.commit()
    for o in orders:
        db.refresh(o)
        try:
            notification_service.create_notification(
                db,
                notification_in=NotificationCreate(
                    user_id=o.seller_id,
                    title="Payment Received",
                    message=f"Order #{o.id[:8].upper()} has been paid via KHQR.",
                    is_read=False
                )
            )
        except Exception:
            pass
    return ("paid", orders)

def get_pending_khqr_payments(db: Session, skip: int = 0, limit: int = 100) -> List[Order]:
    """
    Every KHQR order still awaiting payment confirmation — the admin queue
    for the manual-confirm fallback (confirm_payment_by_admin), used when
    automatic Bakong verification can't run (e.g. the daily call cap is
    exhausted). Excludes cancelled orders, which can never be paid.
    """
    return db.query(Order).options(
        joinedload(Order.buyer), joinedload(Order.seller)
    ).filter(
        Order.payment_method == "KHQR",
        Order.payment_status == "PENDING",
        Order.order_status != "CANCELLED",
    ).order_by(Order.created_at.desc()).offset(skip).limit(limit).all()

def get_order(db: Session, order_id: str) -> Optional[Order]:
    db_order = db.query(Order).options(
        joinedload(Order.buyer), joinedload(Order.seller)
    ).filter(Order.id == order_id).first()

    # Piggyback a re-check onto every read of a still-pending KHQR order —
    # this is what makes tracking automatic: the order-tracking screen's
    # existing poll surfaces a fresh Bakong result on its own, with no
    # manual confirm step from the buyer, seller, or admin.
    if db_order and db_order.payment_method == "KHQR" and db_order.payment_status == "PENDING" and db_order.khqr_md5:
        verify_and_settle_khqr(db, db_order.khqr_md5)
        db.refresh(db_order)

    return db_order

def get_orders_for_user(db: Session, user_id: str, skip: int = 0, limit: int = 100) -> List[Order]:
    return db.query(Order).options(
        joinedload(Order.buyer), joinedload(Order.seller)
    ).filter(
        (Order.buyer_id == user_id) | (Order.seller_id == user_id)
    ).order_by(Order.created_at.desc()).offset(skip).limit(limit).all()

def create_order(db: Session, order_in: OrderCreate, buyer_id: str) -> Order:
    total_amount = 0.0
    total_weight_kg = 0.0
    db_items = []
    seller_id = None
    currency = None

    if not order_in.items:
        raise Exception("NO_ITEMS_IN_ORDER")

    resolved_delivery_method = order_in.delivery_method or "DELIVERY"
    if resolved_delivery_method == "DELIVERY" and (
        order_in.delivery_lat is None or order_in.delivery_lng is None
    ):
        raise Exception("DELIVERY_LOCATION_REQUIRED")

    # Merge repeated lines for the same product first. Validating them
    # separately would let each line pass the stock check on its own while the
    # combined quantity oversells the farmer's inventory.
    merged_quantities: dict[str, float] = {}
    for item in order_in.items:
        merged_quantities[item.product_id] = (
            merged_quantities.get(item.product_id, 0.0) + item.quantity
        )

    # 1. Process and validate line items
    for product_id, quantity in merged_quantities.items():
        db_product = db.query(Product).filter(Product.id == product_id).first()
        if not db_product:
            raise Exception("PRODUCT_NOT_FOUND")
        if float(db_product.quantity_available) < quantity:
            raise Exception("INSUFFICIENT_STOCK")

        # Determine seller_id dynamically from the first item
        if seller_id is None:
            seller_id = db_product.seller_id
            if seller_id == buyer_id:
                raise Exception("CANNOT_ORDER_OWN_PRODUCT")
        elif seller_id != db_product.seller_id:
            raise Exception("MULTIPLE_SELLERS_IN_ORDER")

        # A single order carries one total in one currency — a farmer can list
        # some products in USD and others in KHR, so this cannot be assumed
        # from the seller alone and must be checked per item.
        if currency is None:
            currency = db_product.currency
        elif currency != db_product.currency:
            raise Exception("MULTIPLE_CURRENCIES_IN_ORDER")

        # Calculate subtotal
        subtotal = float(db_product.price_per_unit) * quantity
        total_amount += subtotal

        weight_per_unit = (
            float(db_product.weight_kg_per_unit)
            if db_product.weight_kg_per_unit is not None
            else DEFAULT_WEIGHT_KG_PER_UNIT.get(db_product.unit_type, 1.0)
        )
        total_weight_kg += weight_per_unit * quantity

        # Decrease stock availability
        old_quantity = float(db_product.quantity_available)
        new_quantity = old_quantity - quantity
        db_product.quantity_available = new_quantity

        # Notify only on the crossing, not on every subsequent order once a
        # listing is already known to be low — otherwise a popular low-stock
        # item would spam the farmer with a duplicate alert per sale.
        if new_quantity < LOW_STOCK_THRESHOLD <= old_quantity:
            try:
                notification_service.create_notification(
                    db,
                    notification_in=NotificationCreate(
                        user_id=db_product.seller_id,
                        title="Low Stock Alert",
                        message=f"'{db_product.product_name}' is running low — only {new_quantity:g} left.",
                        is_read=False
                    )
                )
            except Exception:
                pass

        db_items.append(
            OrderItem(
                product_id=product_id,
                quantity=quantity,
                subtotal=subtotal
            )
        )

    if not db_items:
        raise Exception("NO_ITEMS_IN_ORDER")

    # A delivery fee is charged once per order group, same as the goods
    # total — it must live in total_amount itself, since that's the figure
    # the KHQR payment amount is generated from.
    distance_km = DEFAULT_DISTANCE_KM
    if resolved_delivery_method == "DELIVERY":
        seller_user = db.query(User).filter(User.id == seller_id).first()
        if seller_user and seller_user.latitude is not None and seller_user.longitude is not None:
            distance_km = geo_service.haversine_km(
                seller_user.latitude, seller_user.longitude,
                order_in.delivery_lat, order_in.delivery_lng,
            )
        # else: the seller hasn't set a profile location — fall back to
        # DEFAULT_DISTANCE_KM rather than block checkout on their behalf.

    delivery_fee = (
        _delivery_fee_for(currency, distance_km, total_weight_kg)
        if resolved_delivery_method == "DELIVERY" else 0.0
    )
    total_amount += delivery_fee

    # 2. Save order
    db_order = Order(
        buyer_id=buyer_id,
        seller_id=seller_id,
        total_amount=total_amount,
        currency=currency,
        payment_status="PENDING",
        order_status="PLACED",
        payment_method=order_in.payment_method or "KHQR",
        delivery_method=resolved_delivery_method,
        delivery_fee=delivery_fee,
        delivery_address_text=order_in.delivery_address_text if resolved_delivery_method == "DELIVERY" else None,
        delivery_lat=order_in.delivery_lat if resolved_delivery_method == "DELIVERY" else None,
        delivery_lng=order_in.delivery_lng if resolved_delivery_method == "DELIVERY" else None,
        delivery_distance_km=distance_km if resolved_delivery_method == "DELIVERY" else None,
        delivery_weight_kg=total_weight_kg if resolved_delivery_method == "DELIVERY" else None,
    )
    db.add(db_order)
    db.flush() # Flushes order to generate ID

    # 3. Save line items
    for db_item in db_items:
        db_item.order_id = db_order.id
        db.add(db_item)

    # 3b. Seed the delivery tracking record so it exists from the start of
    # the order's life rather than being created ad hoc later.
    if resolved_delivery_method == "DELIVERY":
        db.add(Delivery(order_id=db_order.id, delivery_status="pending"))

    db.commit()
    db.refresh(db_order)

    # 4. Trigger system notification to seller
    try:
        notification_service.create_notification(
            db,
            notification_in=NotificationCreate(
                user_id=seller_id,
                title="New Order Received",
                message=f"You have received a new order of ${total_amount:.2f}.",
                is_read=False
            )
        )
    except Exception:
        pass # Fault tolerance for notifications

    return db_order

def create_order_from_contract(db: Session, contract) -> Order:
    """
    Builds a real, already-paid Order once a contract's final payment
    clears, so delivery fulfillment (Confirm/Ship/Deliver, the live-map
    tracking screen) reuses the order system entirely rather than a second
    parallel implementation for contracts — see
    contract_service._settle_final_payment.

    Deliberately does NOT reuse create_order: no product-stock decrement (a
    wholesale contract was never drawn from the live marketplace stock
    pool, so it shouldn't touch it), no multi-seller/currency
    re-validation (the contract already guarantees both are single), no
    KHQR generation (already paid via the contract's own deposit + final
    payment KHQR).
    """
    total_value = sum(float(item.agreed_price) * float(item.agreed_quantity) for item in contract.items)
    delivery_fee = float(contract.delivery_fee or 0)
    delivery_method = contract.delivery_method or "PICKUP"

    # Contracts don't collect a delivery address today — default from the
    # buyer's saved profile address (same source create_order's distance
    # calc already reads from), or leave it unset. A contract-derived order
    # with no coordinates just shows no map pin, same as any order would.
    buyer = db.query(User).filter(User.id == contract.buyer_id).first()
    delivery_address_text = None
    delivery_lat = None
    delivery_lng = None
    if delivery_method == "DELIVERY" and buyer:
        delivery_lat = buyer.latitude
        delivery_lng = buyer.longitude
        address_parts = [buyer.street_address, buyer.commune, buyer.district, buyer.province]
        delivery_address_text = ", ".join(p for p in address_parts if p) or None

    db_order = Order(
        buyer_id=contract.buyer_id,
        seller_id=contract.seller_id,
        total_amount=total_value + delivery_fee,
        currency=contract.deposit_currency,
        payment_status="PAID",
        order_status="PLACED",
        payment_method="KHQR",
        delivery_method=delivery_method,
        delivery_fee=delivery_fee,
        delivery_address_text=delivery_address_text,
        delivery_lat=delivery_lat,
        delivery_lng=delivery_lng,
    )
    db.add(db_order)
    db.flush()  # Generate ID

    for item in contract.items:
        db.add(OrderItem(
            order_id=db_order.id,
            product_id=item.product_id,
            quantity=item.agreed_quantity,
            subtotal=float(item.agreed_price) * float(item.agreed_quantity),
        ))

    if delivery_method == "DELIVERY":
        db.add(Delivery(order_id=db_order.id, delivery_status="pending"))

    db.commit()
    db.refresh(db_order)
    return db_order

def update_order_status(db: Session, db_order: Order, order_update: OrderUpdate, actor_id: str) -> Order:
    # Only the seller drives fulfillment — the buyer's only lever on order
    # state is cancel_order, matching what the app's UI already exposes.
    if db_order.seller_id != actor_id:
        raise Exception("NOT_AUTHORIZED")

    new_status = order_update.order_status.value
    allowed = ORDER_STATUS_TRANSITIONS.get(db_order.order_status, set())
    if new_status not in allowed:
        raise Exception("INVALID_ORDER_STATUS_TRANSITION")

    # A KHQR order can't be confirmed until the backend has actually
    # verified the money moved — otherwise a seller could start fulfilling
    # (or a buyer could pressure them to) an order nobody paid for.
    if new_status == "CONFIRMED" and db_order.payment_method == "KHQR" and db_order.payment_status != "PAID":
        raise Exception("PAYMENT_NOT_CONFIRMED")

    db_order.order_status = new_status

    delivery = db.query(Delivery).filter(Delivery.order_id == db_order.id).first()
    if new_status == "SHIPPED" and delivery:
        delivery.delivery_status = "in_transit"
        if order_update.contact_phone is not None:
            delivery.contact_phone = order_update.contact_phone
        if order_update.delivery_notes is not None:
            delivery.delivery_notes = order_update.delivery_notes
        if order_update.actual_delivery_cost is not None:
            delivery.actual_delivery_cost = order_update.actual_delivery_cost
    elif new_status == "DELIVERED":
        if delivery:
            delivery.delivery_status = "arrived"
        # Cash on delivery settles the moment goods change hands — nothing
        # else would ever flip this order's payment_status otherwise.
        if db_order.payment_method == "COD" and db_order.payment_status == "PENDING":
            db_order.payment_status = "PAID"

    db.commit()
    db.refresh(db_order)

    try:
        notification_service.create_notification(
            db,
            notification_in=NotificationCreate(
                user_id=db_order.buyer_id,
                title="Order Status Updated",
                message=f"Your order #{db_order.id[:8].upper()} is now {new_status}.",
                is_read=False
            )
        )
    except Exception:
        pass

    return db_order


def confirm_payment_by_admin(db: Session, db_order: Order) -> Order:
    """
    Support-only escape hatch for a KHQR order stuck PENDING despite really
    being paid (e.g. a Bakong outage, or a buyer who paid before the QR's
    md5 was linked correctly) — payment tracking is otherwise fully
    automatic via verify_and_settle_khqr(), so this should be rare. Every
    KHQR order pays into Phsar Kasikor's own merchant account, not the
    seller's, so only admin (who actually holds that account) has any
    firsthand basis for overriding it — the endpoint calling this must be
    admin-only.
    """
    if db_order.payment_status == "PAID":
        raise Exception("ORDER_ALREADY_PAID")

    db_order.payment_status = "PAID"
    db.commit()
    db.refresh(db_order)

    order_ref = db_order.id[:8].upper()
    for user_id, message in (
        (db_order.buyer_id, f"Your payment for order #{order_ref} has been confirmed."),
        (db_order.seller_id, f"Payment for order #{order_ref} has been confirmed — you can proceed to fulfill it."),
    ):
        try:
            notification_service.create_notification(
                db,
                notification_in=NotificationCreate(
                    user_id=user_id,
                    title="Payment Confirmed",
                    message=message,
                    is_read=False
                )
            )
        except Exception:
            pass

    return db_order


def cancel_order(db: Session, order_id: str, current_user_id: str) -> Order:
    db_order = get_order(db, order_id=order_id)
    if not db_order:
        raise Exception("ORDER_NOT_FOUND")

    # Verify authorization: current user must be the buyer or seller of the order
    if db_order.buyer_id != current_user_id and db_order.seller_id != current_user_id:
        raise Exception("NOT_AUTHORIZED")

    # Verify order is in a cancelable state (cannot cancel if shipped, delivered, or already cancelled)
    if db_order.order_status in ["SHIPPED", "DELIVERED", "CANCELLED"]:
        raise Exception("ORDER_CANNOT_BE_CANCELLED")

    # Roll back stock availability
    for item in db_order.items:
        db_product = db.query(Product).filter(Product.id == item.product_id).first()
        if db_product:
            db_product.quantity_available = float(db_product.quantity_available) + float(item.quantity)

    # Update order state
    db_order.order_status = "CANCELLED"

    delivery = db.query(Delivery).filter(Delivery.order_id == db_order.id).first()
    if delivery:
        delivery.delivery_status = "failed"

    db.commit()
    db.refresh(db_order)

    # Trigger system notification to the other party
    try:
        notify_user_id = db_order.seller_id if db_order.buyer_id == current_user_id else db_order.buyer_id
        notify_title = "Order Cancelled by Buyer" if db_order.buyer_id == current_user_id else "Order Cancelled by Seller"
        notify_message = f"Order #{db_order.id} has been cancelled."
        notification_service.create_notification(
            db,
            notification_in=NotificationCreate(
                user_id=notify_user_id,
                title=notify_title,
                message=notify_message,
                is_read=False
            )
        )
    except Exception:
        pass

    return db_order
