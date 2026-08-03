from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.order import Order
from app.models.order_item import OrderItem
from app.models.product import Product
from app.models.user import User
from app.schemas.order import OrderCreate, OrderUpdate
from app.schemas.notification import NotificationCreate
from app.services import notification_service

def get_order(db: Session, order_id: str) -> Optional[Order]:
    return db.query(Order).filter(Order.id == order_id).first()

def get_orders_for_user(db: Session, user_id: str, skip: int = 0, limit: int = 100) -> List[Order]:
    return db.query(Order).filter(
        (Order.buyer_id == user_id) | (Order.seller_id == user_id)
    ).order_by(Order.created_at.desc()).offset(skip).limit(limit).all()

def create_order(db: Session, order_in: OrderCreate, buyer_id: str) -> Order:
    total_amount = 0.0
    db_items = []
    seller_id = None
    currency = None

    if not order_in.items:
        raise Exception("NO_ITEMS_IN_ORDER")

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

        # Decrease stock availability
        db_product.quantity_available = float(db_product.quantity_available) - quantity

        db_items.append(
            OrderItem(
                product_id=product_id,
                quantity=quantity,
                subtotal=subtotal
            )
        )

    if not db_items:
        raise Exception("NO_ITEMS_IN_ORDER")

    # 2. Save order
    db_order = Order(
        buyer_id=buyer_id,
        seller_id=seller_id,
        total_amount=total_amount,
        currency=currency,
        payment_status="PENDING",
        order_status="PLACED",
        payment_method=order_in.payment_method or "KHQR",
        delivery_method=order_in.delivery_method or "DELIVERY"
    )
    db.add(db_order)
    db.flush() # Flushes order to generate ID

    # 3. Save line items
    for db_item in db_items:
        db_item.order_id = db_order.id
        db.add(db_item)

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

def update_order(db: Session, db_order: Order, order_update: OrderUpdate) -> Order:
    update_data = order_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_order, field, value)
    db.commit()
    db.refresh(db_order)
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
