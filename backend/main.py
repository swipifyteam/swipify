# main.py
# FastAPI application entry point for the Swipify ecommerce backend.
# Registers all routers and configures CORS for development.

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Import all route modules
from app.routes import products, brands, cart, vouchers, notifications

# Create the FastAPI app instance
app = FastAPI(
    title="Swipify API",
    description="Backend API for the Swipify Shopee-like ecommerce application",
    version="2.0.0",
)

# Configure CORS — allow all origins for development (restrict to your domain in production)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register all routers with their respective URL prefixes
app.include_router(products.router, prefix="/products", tags=["Products"])
app.include_router(brands.router, prefix="/brands", tags=["Brands"])
app.include_router(cart.router, prefix="/cart", tags=["Cart"])
app.include_router(vouchers.router, prefix="/vouchers", tags=["Vouchers"])
app.include_router(notifications.router, prefix="/notifications", tags=["Notifications"])


@app.get("/")
async def root():
    """Health check endpoint — confirms the Swipify API is running."""
    return {"status": "ok", "message": "Swipify API is running 🚀"}