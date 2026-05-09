from fastapi import HTTPException

# Size Limits in Bytes
MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10MB
MAX_VIDEO_SIZE = 25 * 1024 * 1024  # 25MB

# Allowed MIME Types
ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"]
ALLOWED_VIDEO_TYPES = ["video/mp4", "video/quicktime", "video/webm"]

def validate_image_size(content: bytes):
    if len(content) > MAX_IMAGE_SIZE:
        raise HTTPException(
            status_code=413,
            detail=f"Image file too large. Max size allowed is {MAX_IMAGE_SIZE // (1024 * 1024)}MB"
        )

def validate_video_size(content: bytes):
    if len(content) > MAX_VIDEO_SIZE:
        raise HTTPException(
            status_code=413,
            detail=f"Video file too large. Max size allowed is {MAX_VIDEO_SIZE // (1024 * 1024)}MB"
        )

def validate_media_type(content_type: str, allowed_types: list):
    if content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type: {content_type}. Allowed: {', '.join(allowed_types)}"
        )
