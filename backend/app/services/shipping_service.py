from typing import List, Dict
from app.models.shipping import ShippingItem, ShippingOption
from firebase_client import db

def calculate_shipping_options(items: List[ShippingItem], destination_postal_code: str) -> List[ShippingOption]:
    """
    Calculate shipping options based on items and destination, considering seller origins.

    Logic:
    1. Group items by seller.
    2. For each seller:
       - Fetch shop postal code.
       - Calculate distance-based fee (Seller Origin -> Buyer Destination).
       - Add base per-seller handling fee.
    3. Sum all seller-specific fees.
    4. Provide Standard and Express options.
    """
    if not items:
        raise ValueError("Cannot calculate shipping for an empty list of items.")
    if not destination_postal_code:
        raise ValueError("Destination postal code cannot be empty.")

    # 1. Group by seller
    seller_groups: Dict[str, List[ShippingItem]] = {}
    for item in items:
        if item.seller_id not in seller_groups:
            seller_groups[item.seller_id] = []
        seller_groups[item.seller_id].append(item)

    # 2. Process each seller (kept for future expansion, but currently forcing flat rate)
    # The user strictly requires 120 for Standard and 170 for Express.
    total_standard_fee = 120.0

    # 3. Final Options
    options = [
        ShippingOption(
            id="standard",
            name="Standard",
            fee=round(total_standard_fee, 2),
            estimated_days_min=3,
            estimated_days_max=5
        ),
        ShippingOption(
            id="express",
            name="Express",
            fee=round(total_standard_fee + 50.0, 2), # 120 + 50 = 170
            estimated_days_min=1,
            estimated_days_max=2
        )
    ]

    return options
