# app/seller/routes.py
# Seller API endpoints for Swipify.

from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from app.seller.schemas import (
    SellerApplicationRequest, 
    ApproveRejectRequest, 
    SellerStatusResponse,
    UploadDocumentResponse
)
from app.seller import services

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
