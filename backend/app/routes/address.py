from typing import List

from fastapi import APIRouter, HTTPException, status, Depends
from app.models.address import AddressCreateRequest, AddressUpdateRequest, AddressResponse
from app.services.address_service import (
    create_address_service,
    get_user_addresses_service,
    update_address_service,
    delete_address_service,
    set_default_address_service
)

router = APIRouter()



@router.get("/users/{user_id}/addresses", response_model=List[AddressResponse])
async def get_user_addresses(user_id: str):
    addresses = get_user_addresses_service(user_id)
    return addresses

@router.post("/users/{user_id}/addresses", response_model=AddressResponse, status_code=status.HTTP_201_CREATED)
async def add_user_address(user_id: str, address_data: AddressCreateRequest):
    try:
        created_address = create_address_service(address_data)
        return created_address
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.get("/users/{user_id}/addresses/{address_id}", response_model=AddressResponse)
async def get_user_address_by_id(user_id: str, address_id: str):
    addresses = get_user_addresses_service(user_id)
    address = next((addr for addr in addresses if addr.id == address_id), None)
    if not address:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Address not found")
    return address

@router.put("/users/{user_id}/addresses/{address_id}", response_model=AddressResponse)
async def update_user_address(user_id: str, address_id: str, address_update: AddressUpdateRequest):
    try:
        updated_address = update_address_service(user_id, address_id, address_update)
        return updated_address
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

@router.delete("/users/{user_id}/addresses/{address_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user_address(user_id: str, address_id: str):
    try:
        delete_address_service(user_id, address_id)
        return
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))

@router.put("/users/{user_id}/addresses/{address_id}/set_default", response_model=AddressResponse)
async def set_default_address(user_id: str, address_id: str):
    try:
        updated_address = set_default_address_service(user_id, address_id)
        return updated_address
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
