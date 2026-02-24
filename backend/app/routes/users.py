# backend/routes/users.py
from fastapi import APIRouter

router = APIRouter(prefix="/users", tags=["Users"])

@router.get("/all")
async def get_users():
    return {"users": ["Rosemarie", "John", "Alice"]}