import os
import hmac
import hashlib
import httpx
import base64
from fastapi import HTTPException
from app.config import get_settings

settings = get_settings()

PAYMONGO_PUBLIC_KEY = settings.PAYMONGO_PUBLIC_KEY
PAYMONGO_SECRET_KEY = settings.PAYMONGO_SECRET_KEY
WEBHOOK_SECRET = settings.PAYMONGO_WEBHOOK_SECRET

if not PAYMONGO_SECRET_KEY:
    print("[CRITICAL] PAYMONGO_SECRET_KEY is missing from settings/env!")
else:
    prefix = PAYMONGO_SECRET_KEY[:7] if len(PAYMONGO_SECRET_KEY) > 7 else "???"
    suffix = PAYMONGO_SECRET_KEY[-4:] if len(PAYMONGO_SECRET_KEY) > 4 else "???"
    print(f"[AUTH] PayMongo Secret Key Loaded: {prefix}...{suffix}")

if not PAYMONGO_PUBLIC_KEY:
    print("[CRITICAL] PAYMONGO_PUBLIC_KEY is missing from settings/env!")
else:
    prefix = PAYMONGO_PUBLIC_KEY[:7] if len(PAYMONGO_PUBLIC_KEY) > 7 else "???"
    print(f"[AUTH] PayMongo Public Key Loaded: {prefix}...")

# Redirect URLs — must be valid HTTPS for PayMongo
# In production, replace with your actual domain
REDIRECT_SUCCESS = os.getenv("PAYMENT_REDIRECT_SUCCESS", "https://swipify-app.web.app/payment-success")
REDIRECT_FAILED = os.getenv("PAYMENT_REDIRECT_FAILED", "https://swipify-app.web.app/payment-failed")

# Basic auth requires the secret key as username and empty password
# We ensure PAYMONGO_SECRET_KEY is a string even if None to avoid crash, but it will fail API calls
secret_key = PAYMONGO_SECRET_KEY or ""
auth_token = base64.b64encode(f"{secret_key}:".encode('utf-8')).decode('utf-8')

class PaymentService:
    @staticmethod
    def _get_headers() -> dict:
        """Constructs headers using the current secret key from settings."""
        sk = get_settings().PAYMONGO_SECRET_KEY
        
        if not sk:
            print("[CRITICAL] PAYMONGO_SECRET_KEY is missing during header generation!")
            return {}
            
        auth_token = base64.b64encode(f"{sk}:".encode('utf-8')).decode('utf-8')
        return {
            "accept": "application/json",
            "content-type": "application/json",
            "authorization": f"Basic {auth_token}"
        }

    @staticmethod
    async def create_checkout_session(amount: float, payment_method: str = "gcash") -> dict:
        """
        Creates a checkout session in PayMongo.
        Amount should be in PHP (will be converted to centavos).
        Minimum amount is 100 PHP.
        """
        if amount < 100:
            raise HTTPException(
                status_code=400, 
                detail=f"The minimum payment amount for digital payments is ₱100.00 (Your total: ₱{amount:.2f}). Please add more items to your cart or choose Cash on Delivery."
            )
        
        # Round to avoid float issues before converting to centavos
        amount_centavos = int(round(amount, 2) * 100)
        
        # Map frontend payment methods to PayMongo types
        payment_method_types = ["gcash"]
        if payment_method == "card":
            payment_method_types = ["card"]
        elif payment_method == "gcash":
            payment_method_types = ["gcash"]
        else:
            payment_method_types = ["gcash", "card", "grab_pay", "paymaya"]

        payload = {
            "data": {
                "attributes": {
                    "send_email_receipt": True,
                    "show_description": True,
                    "show_line_items": True,
                    "payment_method_types": payment_method_types,
                    "line_items": [
                        {
                            "currency": "PHP",
                            "amount": amount_centavos,
                            "description": "Swipify Order Payment",
                            "name": "Order Payment",
                            "quantity": 1
                        }
                    ],
                    "success_url": REDIRECT_SUCCESS,
                    "cancel_url": REDIRECT_FAILED,
                    "description": "Payment for Swipify Order"
                }
            }
        }
        
        headers = PaymentService._get_headers()
        if not headers:
            raise HTTPException(status_code=500, detail="Payment service configuration error (missing API key)")

        async with httpx.AsyncClient() as client:
            print(f"[PAYMENT] Requesting PayMongo Checkout Session for amount: {amount} PHP ({amount_centavos} centavos)")
            response = await client.post(
                "https://api.paymongo.com/v1/checkout_sessions",
                json=payload,
                headers=headers
            )
            
            if response.status_code >= 400:
                error_detail = response.text
                try:
                    error_json = response.json()
                    # PayMongo usually returns errors in an 'errors' array
                    if "errors" in error_json:
                        error_detail = error_json["errors"][0].get("detail", response.text)
                except:
                    pass
                
                print(f"[PAYMONGO ERROR] Status: {response.status_code}, Detail: {error_detail}")
                raise HTTPException(status_code=response.status_code, detail=f"PayMongo Error: {error_detail}")
                
            data = response.json()
            return {
                "id": data["data"]["id"],
                "checkout_url": data["data"]["attributes"]["checkout_url"]
            }

    @staticmethod
    def verify_webhook_signature(payload: bytes, signature_header: str) -> bool:
        """
        Verifies the signature of the webhook payload sent by PayMongo.
        signature_header is the 'Paymongo-Signature' header.
        """
        if not signature_header or not WEBHOOK_SECRET:
            return False
            
        try:
            # signature_header format: t=1617154213,te=...,li=...
            parts = signature_header.split(",")
            t = ""
            te = ""
            
            for part in parts:
                if part.startswith("t="):
                    t = part[2:]
                elif part.startswith("te="):
                    te = part[3:]
                    
            if not t or not te:
                return False
                
            # Construct the signed string
            signed_string = f"{t}.{payload.decode('utf-8')}"
            
            # Compute HMAC SHA256 signature
            expected_signature = hmac.new(
                key=WEBHOOK_SECRET.encode('utf-8'),
                msg=signed_string.encode('utf-8'),
                digestmod=hashlib.sha256
            ).hexdigest()
            
            # Use hmac.compare_digest to prevent timing attacks
            return hmac.compare_digest(expected_signature, te)
            
        except Exception:
            return False
