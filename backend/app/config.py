from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    # Cloudinary
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""

    # Firebase
    FIREBASE_SERVICE_ACCOUNT_PATH: str = "serviceAccountKey.json"

    # Admin Settings
    DASHBOARD_STATS_CACHE_HOURS: int = 1

    class Config:
        env_file = ".env"

@lru_cache()
def get_settings():
    return Settings()
