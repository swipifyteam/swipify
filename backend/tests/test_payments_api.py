import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch

@pytest.fixture
def test_client():
    from main import app
    return TestClient(app)

def test_create_payment_session_api(test_client, mock_firebase_auth):
    mock_firebase_auth.return_value = {"uid": "user_123"}
    
    with patch("app.routes.payments.PaymentService.create_checkout_session") as mock_create, \
         patch("app.routes.payments.db.collection") as mock_db:
        mock_create.return_value = {
            "id": "cs_12345",
            "checkout_url": "https://test.paymongo.com/checkout"
        }
        
        # Mock Firestore set
        mock_db.return_value.document.return_value.set.return_value = None
        
        response = test_client.post(
            "/payments/create",
            headers={"Authorization": "Bearer fake_token"},
            json={
                "seller_groups": [
                    {
                        "seller_id": "seller_1",
                        "items": [
                            {"product_id": "p1", "name": "Prod 1", "price": 100.0, "quantity": 1}
                        ],
                        "total_price": 100.0,
                        "discount_amount": 0.0
                    }
                ],
                "amount": 100.0,
                "payment_method": "gcash",
                "shipping_option": {
                    "id": "ship_1",
                    "name": "Standard",
                    "fee": 0.0,
                    "estimated_days_min": 1,
                    "estimated_days_max": 3
                },
                "shipping_address": {
                    "full_name": "John Doe",
                    "phone": "123",
                    "region": "NCR",
                    "city": "Manila",
                    "barangay": "123",
                    "street": "123 St",
                    "postal_code": "1000"
                }
            }
        )
        
        assert response.status_code == 200
        assert response.json()["checkout_url"] == "https://test.paymongo.com/checkout"
        mock_create.assert_called_once_with(100.0, "gcash")
            
def test_create_payment_session_amount_mismatch(test_client, mock_firebase_auth):
    mock_firebase_auth.return_value = {"uid": "user_123"}
    
    response = test_client.post(
        "/payments/create",
        headers={"Authorization": "Bearer fake_token"},
        json={
            "seller_groups": [
                {
                    "seller_id": "seller_1",
                    "items": [
                        {"product_id": "p1", "name": "Prod 1", "price": 100.0, "quantity": 1}
                    ],
                    "total_price": 100.0
                }
            ],
            "amount": 50.0,  # Mismatch: 100 + 0 - 0 != 50
            "payment_method": "gcash",
            "shipping_option": {
                "id": "ship_1",
                "name": "Standard",
                "fee": 0.0,
                "estimated_days_min": 1,
                "estimated_days_max": 3
            },
            "shipping_address": {
                "full_name": "John Doe",
                "phone": "123",
                "region": "NCR",
                "city": "Manila",
                "barangay": "123",
                "street": "123 St",
                "postal_code": "1000"
            }
        }
    )
    
    assert response.status_code == 400
    assert "Amount mismatch" in response.json()["detail"]
