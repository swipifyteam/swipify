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
  api_secret=os.getenv("CLOUDINARY_API_SECRET", "YOUR_API_SECRET")
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
        print(f"[UPLOAD] Image URL: {url}")
        return url
    except Exception as e:
        print(f"[UPLOAD] Error uploading to Cloudinary: {e}")
        raise e
