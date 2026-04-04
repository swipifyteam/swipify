# main.py
# FastAPI application entry point for the Swipify ecommerce backend.
# Registers all routers and configures CORS for development.

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

# Import all route modules
from app.routes import products, brands, cart, vouchers, notifications, engagement, users, orders
from app.seller import routes as seller_routes
from app.seller import seller_products
from app.seller import inventory
from app.seller import orders_seller

# Create the FastAPI app instance
app = FastAPI(
    title="Swipify API",
    description="Backend API for the Swipify",
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
app.include_router(seller_routes.router, prefix="/seller", tags=["Seller & Admin"])
app.include_router(seller_products.router, prefix="/seller/products", tags=["Seller - Products"])
app.include_router(inventory.router, prefix="/seller/inventory", tags=["Seller - Inventory"])
app.include_router(orders_seller.router, prefix="/seller/orders", tags=["Seller - Orders"])
app.include_router(users.router, prefix="/users", tags=["Users"])
app.include_router(orders.router, prefix="/orders", tags=["Orders"])
from app.utils.cloudinary_handler import upload_image_to_cloudinary
import uuid

@app.post("/upload-image", tags=["Upload"])
async def upload_image(file: UploadFile = File(...)):
    """Generic image upload to Cloudinary. Returns the secure CDN URL."""
    try:
        print(f"[API] Generic upload reached for: {file.filename}")
        contents = await file.read()
        unique_filename = f"{uuid.uuid4()}_{file.filename}"
        url = upload_image_to_cloudinary(contents, unique_filename)
        return {"image_url": url}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
async def root():
    """Health check endpoint — confirms the Swipify API is running."""
    return {"status": "ok", "message": "Swipify API is running 🚀"}