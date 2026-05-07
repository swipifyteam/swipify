# app/utils/cloudinary_handler.py
import cloudinary
import cloudinary.uploader
import os
from dotenv import load_dotenv

load_dotenv()

# Configure Cloudinary
# Ensure you set these in your .env or system environment
cloudinary.config(
  cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME", "YOUR_CLOUD_NAME"),
  api_key=os.getenv("CLOUDINARY_API_KEY", "YOUR_API_KEY"),
  api_secret=os.getenv("CLOUDINARY_API_SECRET", "YOUR_API_SECRET"),
  secure=True
)

def upload_image_to_cloudinary(file_bytes: bytes, filename: str, folder: str = "swipify_products"):
    """
    Uploads an image's raw bytes to Cloudinary.
    Returns the secure URL.
    """
    try:
        print(f"[UPLOAD] Uploading image to Cloudinary: {filename}")
        upload_result = cloudinary.uploader.upload(
            file_bytes,
            public_id=filename.split('.')[0] if '.' in filename else filename,
            folder=folder,
            overwrite=True,
            resource_type="image"
        )
        url = upload_result.get("secure_url")
        return url
    except Exception as e:
        print(f"[UPLOAD] Error uploading to Cloudinary: {e}")
        raise e

def upload_media_to_cloudinary(file_bytes: bytes, filename: str, folder: str = "swipify_chat"):
    """
    Uploads an image or video raw bytes to Cloudinary.
    Uses resource_type="auto" so Cloudinary detects if it's an image or video.
    Returns the secure URL.
    """
    try:
        print(f"[UPLOAD] Uploading media to Cloudinary: {filename}")
        upload_result = cloudinary.uploader.upload(
            file_bytes,
            public_id=filename.split('.')[0] if '.' in filename else filename,
            folder=folder,
            overwrite=True,
            resource_type="auto"
        )
        url = upload_result.get("secure_url")
        print(f"[UPLOAD] Media URL: {url}")
        return url
    except Exception as e:
        print(f"[UPLOAD] Error uploading media to Cloudinary: {e}")
        raise e
def upload_video_to_cloudinary(file_bytes: bytes, filename: str, folder: str = "swipify/products/videos"):
    """
    Uploads a video to Cloudinary.
    Returns the secure URL and a thumbnail URL.
    """
    try:
        print("[VIDEO RECEIVED]")
        # 100MB Limit check
        if len(file_bytes) > 100 * 1024 * 1024:
            raise Exception("Video file too large (Max 100MB)")

        upload_result = cloudinary.uploader.upload(
            file_bytes,
            resource_type="video",
            folder=folder,
            public_id=filename.split('.')[0] if '.' in filename else filename,
            overwrite=True
        )
        
        video_url = upload_result.get("secure_url")
        print("[VIDEO UPLOADED]")
        
        # Generate thumbnail URL from the video (first frame)
        public_id = upload_result.get("public_id")
        thumbnail_url = cloudinary.utils.cloudinary_url(
            public_id, 
            resource_type="video", 
            format="jpg", 
            transformation=[
                {"width": 400, "crop": "scale"},
                {"start_offset": 0}
            ]
        )[0]
        
        print("[THUMBNAIL GENERATED]")
        return video_url, thumbnail_url
    except Exception as e:
        print(f"[UPLOAD] Error uploading video to Cloudinary: {e}")
        raise e
