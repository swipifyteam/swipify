# test_cloudinary.py
import os
import requests
from dotenv import load_dotenv

load_dotenv()

def test_config():
    cloud = os.getenv("CLOUDINARY_CLOUD_NAME")
    key = os.getenv("CLOUDINARY_API_KEY")
    secret = os.getenv("CLOUDINARY_API_SECRET")
    
    print(f"Cloud Name: {cloud}")
    print(f"API Key: {key}")
    print(f"API Secret: {'*' * 5 if secret else 'NONE'}")
    
    if not all([cloud, key, secret]):
        print("❌ MISSING KEYS!")
    else:
        print("✅ KEYS FOUND!")

if __name__ == "__main__":
    test_config()
