# seed_firestore.py
# Seed script to populate Firestore with initial data for Swipify.
# Run ONCE after enabling Firestore: python seed_firestore.py
# Make sure the backend venv is activated before running.

from firebase_client import db
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from datetime import datetime

print("🌱 Seeding Swipify Firestore database...")

# ── BRANDS ───────────────────────────────────────────────────────────────────
brands = [
    {
        "id": "nike",
        "name": "Nike",
        "tagline": "Just Do It",
        "description": "The world's leading athletic footwear and apparel brand, inspiring athletes everywhere.",
        "logoUrl": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Logo_NIKE.svg/512px-Logo_NIKE.svg.png",
        "bannerUrl": "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=800&q=80",
    },
    {
        "id": "samsung",
        "name": "Samsung",
        "tagline": "Do What You Can't",
        "description": "A global leader in technology, delivering cutting-edge mobile, TV, and home appliance products.",
        "logoUrl": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Samsung_Logo.svg/512px-Samsung_Logo.svg.png",
        "bannerUrl": "https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=800&q=80",
    },
    {
        "id": "apple",
        "name": "Apple",
        "tagline": "Think Different",
        "description": "Innovative technology products that seamlessly blend hardware, software, and services.",
        "logoUrl": "https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Apple_logo_black.svg/200px-Apple_logo_black.svg.png",
        "bannerUrl": "https://images.unsplash.com/photo-1611532736597-de2d4265fba3?w=800&q=80",
    },
    {
        "id": "adidas",
        "name": "Adidas",
        "tagline": "Impossible Is Nothing",
        "description": "Premium sportswear and lifestyle brand known for iconic designs and performance gear.",
        "logoUrl": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/20/Adidas_Logo.svg/512px-Adidas_Logo.svg.png",
        "bannerUrl": "https://images.unsplash.com/photo-1542332213-31f87348057f?w=800&q=80",
    },
    {
        "id": "sony",
        "name": "Sony",
        "tagline": "Be Moved",
        "description": "World-class audio, gaming, and entertainment products that move the world.",
        "logoUrl": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/Sony_logo.svg/512px-Sony_logo.svg.png",
        "bannerUrl": "https://images.unsplash.com/photo-1511268011861-8aa3df734a24?w=800&q=80",
    },
    {
        "id": "logitech",
        "name": "Logitech",
        "tagline": "Designed for Creators",
        "description": "Premium peripherals and workspace accessories for gamers, creators, and professionals.",
        "logoUrl": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/45/Logitech_logo_2015.svg/512px-Logitech_logo_2015.svg.png",
        "bannerUrl": "https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=800&q=80",
    },
]

for brand in brands:
    brand_id = brand.pop("id")
    db.collection("brands").document(brand_id).set(brand)
    print(f"  ✅ Brand: {brand['name']}")

# ── PRODUCTS ──────────────────────────────────────────────────────────────────
products = [
    # Nike
    {
        "id": "nike-air-max-270",
        "name": "Nike Air Max 270",
        "brandId": "nike",
        "price": 6499.00,
        "stock": 50,
        "description": "The Nike Air Max 270 delivers visible cushioning under every step. Updated details nod to the original.",
        "images": ["https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400&q=80"],
        "rating": 4.8,
        "createdAt": datetime.utcnow().isoformat(),
    },
    {
        "id": "nike-react-infinity",
        "name": "Nike React Infinity Run",
        "brandId": "nike",
        "price": 7999.00,
        "stock": 30,
        "description": "Designed to help reduce injury and keep you on the run. More foam, more cushion.",
        "images": ["https://images.unsplash.com/photo-1604480132736-44c188fe4d20?w=400&q=80"],
        "rating": 4.7,
        "createdAt": datetime.utcnow().isoformat(),
    },
    # Samsung
    {
        "id": "samsung-galaxy-s24",
        "name": "Samsung Galaxy S24 Ultra",
        "brandId": "samsung",
        "price": 54990.00,
        "stock": 20,
        "description": "The ultimate Galaxy experience with Galaxy AI built in. Titanium frame, 200MP camera.",
        "images": ["https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=400&q=80"],
        "rating": 4.9,
        "createdAt": datetime.utcnow().isoformat(),
    },
    {
        "id": "samsung-galaxy-buds2",
        "name": "Samsung Galaxy Buds2 Pro",
        "brandId": "samsung",
        "price": 8990.00,
        "stock": 80,
        "description": "Intelligent Active Noise Cancellation blocks out the world so you can focus on what matters.",
        "images": ["https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=400&q=80"],
        "rating": 4.5,
        "createdAt": datetime.utcnow().isoformat(),
    },
    # Apple
    {
        "id": "apple-iphone-15",
        "name": "Apple iPhone 15 Pro",
        "brandId": "apple",
        "price": 59990.00,
        "stock": 15,
        "description": "Titanium design. Powerful A17 Pro chip. And a hugely versatile Pro camera system.",
        "images": ["https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=400&q=80"],
        "rating": 4.9,
        "createdAt": datetime.utcnow().isoformat(),
    },
    {
        "id": "apple-airpods-pro",
        "name": "Apple AirPods Pro (2nd Gen)",
        "brandId": "apple",
        "price": 14990.00,
        "stock": 45,
        "description": "Up to 2x more Active Noise Cancellation. Adaptive Audio. Personalized Spatial Audio.",
        "images": ["https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?w=400&q=80"],
        "rating": 4.8,
        "createdAt": datetime.utcnow().isoformat(),
    },
    # Adidas
    {
        "id": "adidas-ultraboost-23",
        "name": "Adidas Ultraboost 23",
        "brandId": "adidas",
        "price": 8999.00,
        "stock": 40,
        "description": "Our most responsive running shoes yet, with premium BOOST cushioning for every stride.",
        "images": ["https://images.unsplash.com/photo-1587563871167-1ee9c731aefb?w=400&q=80"],
        "rating": 4.7,
        "createdAt": datetime.utcnow().isoformat(),
    },
    {
        "id": "adidas-classic-backpack",
        "name": "Adidas Classic Backpack",
        "brandId": "adidas",
        "price": 3499.00,
        "stock": 100,
        "description": "Carry your essentials in style. Durable ripstop fabric with multiple compartments.",
        "images": ["https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400&q=80"],
        "rating": 4.3,
        "createdAt": datetime.utcnow().isoformat(),
    },
    # Sony
    {
        "id": "sony-wh1000xm5",
        "name": "Sony WH-1000XM5 Headphones",
        "brandId": "sony",
        "price": 19990.00,
        "stock": 25,
        "description": "Industry-leading noise canceling with 8 microphones. Up to 30 hours of battery life.",
        "images": ["https://images.unsplash.com/photo-1618366712010-f4ae9c647dcb?w=400&q=80"],
        "rating": 4.9,
        "createdAt": datetime.utcnow().isoformat(),
    },
    {
        "id": "sony-playstation-5",
        "name": "Sony PlayStation 5",
        "brandId": "sony",
        "price": 29990.00,
        "stock": 10,
        "description": "Experience lightning-fast loading, deeper immersion with haptic feedback and 4K gaming.",
        "images": ["https://images.unsplash.com/photo-1607853202273-797f1c22a38e?w=400&q=80"],
        "rating": 4.9,
        "createdAt": datetime.utcnow().isoformat(),
    },
    # Logitech
    {
        "id": "logitech-mx-master-3s",
        "name": "Logitech MX Master 3S",
        "brandId": "logitech",
        "price": 5495.00,
        "stock": 60,
        "description": "The master of mice, perfected. Ultra-quiet clicks, MagSpeed scroll wheel, and ergonomic design.",
        "images": ["https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=400&q=80"],
        "rating": 4.8,
        "createdAt": datetime.utcnow().isoformat(),
    },
    {
        "id": "logitech-g502-x",
        "name": "Logitech G502 X Gaming Mouse",
        "brandId": "logitech",
        "price": 4495.00,
        "stock": 55,
        "description": "HERO 25K sensor. Lightforce hybrid switches. The most advanced G502 ever built.",
        "images": ["https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=400&q=80"],
        "rating": 4.7,
        "createdAt": datetime.utcnow().isoformat(),
    },
]

for product in products:
    product_id = product.pop("id")
    db.collection("products").document(product_id).set(product)
    print(f"  ✅ Product: {product['name']}")

# ── VOUCHERS ──────────────────────────────────────────────────────────────────
vouchers = [
    {
        "id": "voucher-free-shipping",
        "title": "Free Shipping Voucher",
        "description": "Get free shipping on your next order",
        "discountType": "shipping",
        "discountValue": 100,
        "minimumSpend": 500,
        "expiryDate": "2026-12-31",
        "brandId": None,  # Platform-wide voucher
    },
    {
        "id": "voucher-15off",
        "title": "15% Off Your Order",
        "description": "Enjoy 15% off sitewide, no minimum spend required",
        "discountType": "percentage",
        "discountValue": 15,
        "minimumSpend": 0,
        "expiryDate": "2026-06-30",
        "brandId": None,
    },
    {
        "id": "voucher-nike-200off",
        "title": "Nike ₱200 Off",
        "description": "Save ₱200 on any Nike product over ₱3,000",
        "discountType": "fixed",
        "discountValue": 200,
        "minimumSpend": 3000,
        "expiryDate": "2026-04-30",
        "brandId": "nike",
    },
    {
        "id": "voucher-samsung-500off",
        "title": "Samsung ₱500 Off",
        "description": "Save ₱500 on Samsung electronics over ₱10,000",
        "discountType": "fixed",
        "discountValue": 500,
        "minimumSpend": 10000,
        "expiryDate": "2026-05-31",
        "brandId": "samsung",
    },
]

for voucher in vouchers:
    voucher_id = voucher.pop("id")
    db.collection("vouchers").document(voucher_id).set(voucher)
    print(f"  ✅ Voucher: {voucher['title']}")

print("\n✅ Firestore seeding complete! All collections are ready.")
