import httpx
import logging
from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

class SmsService:
    API_URL = "https://smsapiph.onrender.com/api/v1/send/sms"

    @staticmethod
    async def send_otp(phone_number: str, otp: str):
        """
        Sends an OTP via SMS API PH.
        Expected format: +639#########
        """
        headers = {
            "x-api-key": settings.SMS_KEY,
            "Content-Type": "application/json"
        }
        payload = {
            "recipient": phone_number,
            "message": f"Your Swipify verification code is {otp}. Valid for 5 minutes."
        }

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(SmsService.API_URL, headers=headers, json=payload, timeout=10.0)
                
                if response.status_code == 200:
                    logger.info(f"OTP sent successfully to {phone_number}")
                    return True
                else:
                    logger.error(f"Failed to send OTP to {phone_number}: {response.text}")
                    return False
        except Exception as e:
            logger.error(f"SMS API error: {str(e)}")
            return False

sms_service = SmsService()
