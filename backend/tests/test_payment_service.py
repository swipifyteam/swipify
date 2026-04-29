import pytest
import hmac
import hashlib
import json
from unittest.mock import patch, MagicMock
from app.services.payment_service import PaymentService

# Dummy payload and secrets for testing
DUMMY_SECRET = "whsk_test_secret123"
DUMMY_PAYLOAD = b'{"data": {"type": "event"}}'

def test_create_checkout_session_success():
    """Test creating a PayMongo checkout session successfully."""
    # Mock the HTTP client post and settings
    with patch("httpx.AsyncClient.post") as mock_post, \
         patch("app.services.payment_service.get_settings") as mock_get_settings:
        
        mock_settings = MagicMock()
        mock_settings.PAYMONGO_SECRET_KEY = "sk_test_123"
        mock_get_settings.return_value = mock_settings

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "data": {
                "id": "cs_12345",
                "attributes": {
                    "checkout_url": "https://test.paymongo.com/checkout"
                }
            }
        }
        mock_post.return_value = mock_response

        import asyncio
        result = asyncio.run(PaymentService.create_checkout_session(150.0, "gcash"))
        
        assert result["id"] == "cs_12345"
        assert result["checkout_url"] == "https://test.paymongo.com/checkout"
        
        # Verify PayMongo uses amounts in centavos (150.0 -> 15000)
        mock_post.assert_called_once()
        call_kwargs = mock_post.call_args.kwargs
        # In checkout_sessions, amount is inside line_items
        assert call_kwargs["json"]["data"]["attributes"]["line_items"][0]["amount"] == 15000

def test_verify_webhook_signature_valid():
    """Test valid PayMongo webhook signature verification."""
    timestamp = "1617154213"
    te = f"{timestamp}.{DUMMY_PAYLOAD.decode('utf-8')}"
    
    # Generate valid signature
    signature = hmac.new(
        key=DUMMY_SECRET.encode('utf-8'),
        msg=te.encode('utf-8'),
        digestmod=hashlib.sha256
    ).hexdigest()
    
    signature_header = f"t={timestamp},te={signature},li=somethingelse"
    
    with patch("app.services.payment_service.WEBHOOK_SECRET", DUMMY_SECRET):
        assert PaymentService.verify_webhook_signature(DUMMY_PAYLOAD, signature_header) == True

def test_verify_webhook_signature_invalid():
    """Test invalid PayMongo webhook signature verification."""
    timestamp = "1617154213"
    signature_header = f"t={timestamp},te=invalid_signature"
    
    with patch("app.services.payment_service.WEBHOOK_SECRET", DUMMY_SECRET):
        assert PaymentService.verify_webhook_signature(DUMMY_PAYLOAD, signature_header) == False
