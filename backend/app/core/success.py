# Centralized Success Response Codes and Mapped Messages

# --------- Auth Success --------- #
LOGIN_SUCCESS = "LOGIN_SUCCESS"
LOGOUT_SUCCESS = "LOGOUT_SUCCESS"

# --------- Category Success --------- #
CATEGORY_DELETED = "CATEGORY_DELETED"
CATEGORY_CREATED = "CATEGORY_CREATED"
CATEGORY_UPDATED = "CATEGORY_UPDATED"

# --------- Product Success --------- #
PRODUCT_DELETED = "PRODUCT_DELETED"
PRODUCT_CREATED = "PRODUCT_CREATED"
PRODUCT_UPDATED = "PRODUCT_UPDATED"
ORDER_PLACED = "ORDER_PLACED"
ORDER_CANCELLED = "ORDER_CANCELLED"

def make_success_response(code: str, custom_message: str = None):
  return {
    "success": True,
    "message": custom_message or code
  }
