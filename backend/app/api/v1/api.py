from fastapi import APIRouter

from app.api.v1.endpoints import auth, users, roles, products, categories, market_prices, orders, contracts, deliveries, notifications, chat, upload, locations, address_requests

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(categories.router, prefix="/categories", tags=["Categories"])
api_router.include_router(chat.router, prefix="/chat", tags=["Chat"])
api_router.include_router(contracts.router, prefix="/contracts", tags=["Contracts"])
api_router.include_router(deliveries.router, prefix="/deliveries", tags=["Deliveries"])
api_router.include_router(market_prices.router, prefix="/market-prices", tags=["Market Prices"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["Notifications"])
api_router.include_router(orders.router, prefix="/orders", tags=["Orders"])
api_router.include_router(products.router, prefix="/products", tags=["Products"])
api_router.include_router(roles.router, prefix="/roles", tags=["Roles"])
api_router.include_router(users.router, prefix="/users", tags=["Users"])
api_router.include_router(upload.router, prefix="/upload", tags=["Upload"])
api_router.include_router(locations.router, prefix="/locations", tags=["Locations"])
api_router.include_router(address_requests.router, prefix="/address-requests", tags=["Address Requests"])
