from pydantic_settings import BaseSettings
from pydantic import ConfigDict
from functools import lru_cache

class Settings(BaseSettings):
    model_config = ConfigDict(env_file=".env", extra="ignore")

    # Cloudinary
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""

    # PayMongo
    PAYMONGO_PUBLIC_KEY: str = ""
    PAYMONGO_SECRET_KEY: str = ""
    PAYMONGO_WEBHOOK_SECRET: str = ""

    # Firebase
    FIREBASE_SERVICE_ACCOUNT_PATH: str = "serviceAccountKey.json"

    # Admin Settings
    DASHBOARD_STATS_CACHE_HOURS: int = 1

@lru_cache()
def get_settings():
    return Settings()
