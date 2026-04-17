from fastapi import APIRouter

router = APIRouter()

@router.get("")
def get_categories():
    """Fetch all available product categories."""
    return [
        "Electronics",
        "Clothing",
        "Footwear",
        "Accessories",
        "Home & Living",
        "Beauty",
        "Sports"
    ]
