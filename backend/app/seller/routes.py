from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Depends
from app.seller.schemas import (
    SellerApplicationRequest, 
    ApproveRejectRequest, 
    SellerStatusResponse,
    UploadDocumentResponse
)
from app.seller import services
from app.utils.auth_utils import get_current_user_id

router = APIRouter()

@router.get("/status/{user_id}", response_model=SellerStatusResponse)
async def get_seller_status(user_id: str):
    """Get the current seller application status for a user."""
    result = services.get_seller_status(user_id)
    return result

@router.post("/apply")
async def apply_seller(request: SellerApplicationRequest):
    """Submit a new seller application."""
    success, result = services.apply_seller(request)
    if not success:
        raise HTTPException(status_code=409, detail=result)
    return {"message": "Application submitted successfully", "seller": result}

@router.post("/upload-document")
async def upload_document(
    seller_id: str = Form(...),
    doc_type: str = Form(...), # id_front, selfie, business_reg
    file: UploadFile = File(...)
):
    """Upload a seller document (multipart/form-data)."""
    try:
        file_bytes = await file.read()
        success, result = services.upload_document(
            seller_id, 
            doc_type, 
            file_bytes, 
            file.filename,
            file.content_type
        )
        
        if not success:
            raise HTTPException(status_code=400, detail=result)
            
        return UploadDocumentResponse(
            message="Document uploaded successfully",
            file_url=result,
            document_id=doc_type
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/admin/sellers")
async def get_all_sellers():
    """Get all seller applications for admin."""
    from firebase_client import db
    try:
        docs = db.collection("sellers").get()
        sellers = []
        for doc in docs:
            seller = doc.to_dict()
            seller["id"] = doc.id
            sellers.append(seller)
        return {"sellers": sellers}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/upload-identity")
async def upload_identity(file: UploadFile = File(...)):
    """Generic upload for identity verification images (to Cloudinary)."""
    try:
        file_bytes = await file.read()
        file_url = services.upload_image_to_cloudinary(file_bytes, file.filename, folder="identities")
        
        if not file_url:
            raise HTTPException(status_code=400, detail="Failed to upload to Cloudinary")
            
        return {"image_url": file_url}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/admin/approve")
async def admin_approve_seller(request: ApproveRejectRequest):
    """Admin endpoint to approve a seller."""
    success, result = services.approve_seller(request.seller_id)
    if not success:
        raise HTTPException(status_code=404, detail=result)
    return {"message": result}

@router.post("/admin/reject")
async def admin_reject_seller(request: ApproveRejectRequest):
    """Admin endpoint to reject a seller."""
    success, result = services.reject_seller(request.seller_id, request.reason)
    if not success:
        raise HTTPException(status_code=404, detail=result)
    return {"message": result}

@router.get("/shop/{seller_id}")
async def get_shop_settings(seller_id: str, current_user_id: str = Depends(get_current_user_id)):
    """Retrieve shop settings for a seller (Private: Requires ownership)."""
    if seller_id != current_user_id:
        raise HTTPException(status_code=403, detail="Not authorized to access this shop")
    return services.get_shop_settings(seller_id)

@router.get("/shop/{seller_id}/public")
async def get_public_shop_info(seller_id: str):
    """Retrieve public shop information for customers (No Auth required)."""
    full_settings = services.get_shop_settings(seller_id)
    # Filter out sensitive fields
    public_info = {
        "shop_name": full_settings.get("shop_name", "My Shop"),
        "description": full_settings.get("description", ""),
        "logo_url": full_settings.get("logo_url"),
        "banner_url": full_settings.get("banner_url"),
        "vacation_mode": full_settings.get("vacation_mode", False),
        "follower_count": full_settings.get("follower_count", 0),
        "rating": full_settings.get("rating", 5.0),
        "review_count": full_settings.get("review_count", 0),
    }
    return public_info


@router.patch("/shop/{seller_id}")
async def update_shop_settings(seller_id: str, data: dict, current_user_id: str = Depends(get_current_user_id)):
    """Update shop settings for a seller."""
    if seller_id != current_user_id:
        raise HTTPException(status_code=403, detail="Not authorized to update this shop")
    success, message = services.update_shop_settings(seller_id, data)
    if not success:
        raise HTTPException(status_code=400, detail=message)
    return {"message": message}
