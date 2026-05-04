import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock

@pytest.fixture
def test_client():
    from main import app
    return TestClient(app)

def test_paymongo_webhook_unauthorized(test_client):
    # Simulate a webhook call without a valid signature
    response = test_client.post(
        "/payments/webhook",
        headers={"paymongo-signature": "invalid_sig"},
        json={"data": {"attributes": {"type": "payment.paid"}}}
    )
    
    assert response.status_code == 401
    assert "Invalid webhook signature" in response.json()["detail"]

def test_paymongo_webhook_payment_paid(test_client):
    # Simulate a webhook call with a valid signature and checkout_session.payment_paid event
    with patch("app.routes.payments.PaymentService.verify_webhook_signature") as mock_verify:
        mock_verify.return_value = True
        
        with patch("app.routes.payments.create_order_service") as mock_create_order, \
             patch("app.routes.payments.db.collection") as mock_db_collection:
             
            # Mock session lookup
            mock_session_doc = MagicMock()
            mock_session_doc.exists = True
            mock_session_doc.to_dict.return_value = {
                "user_id": "user_123",
                "payment_method": "gcash",
                "shipping_option": {
                    "id": "ship_1",
                    "name": "Standard",
                    "fee": 50.0,
                    "estimated_days_min": 1,
                    "estimated_days_max": 3
                },
                "shipping_address": {
                    "full_name": "Test User",
                    "phone": "09123456789",
                    "region": "NCR",
                    "city": "Manila",
                    "barangay": "123",
                    "street": "123 St",
                    "postal_code": "1000"
                },
                "seller_groups": [
                    {
                        "seller_id": "seller_1",
                        "items": [{"product_id": "p1", "name": "Item 1", "price": 100.0, "quantity": 1}],
                        "total_price": 100.0
                    }
                ]
            }
            mock_db_collection.return_value.document.return_value.get.return_value = mock_session_doc
            
            # Mock order creation
            mock_create_order.return_value = {"id": "order_abc"}
            
            # Mock document update
            mock_update = MagicMock()
            mock_db_collection.return_value.document.return_value.update = mock_update

            response = test_client.post(
                "/payments/webhook",
                headers={"paymongo-signature": "valid_sig"},
                json={
                    "data": {
                        "attributes": {
                            "type": "checkout_session.payment_paid",
                            "data": {
                                "id": "cs_123"
                            }
                        }
                    }
                }
            )
            
            assert response.status_code == 200
            assert response.json()["status"] == "success"
            
            # Verify order creation was called
            mock_create_order.assert_called_once()
            
            # Verify order was marked as paid (update call)
            # The code calls .update twice: once for the order, once for the session.
            # We check if 'paid' was passed to any of the update calls.
            update_calls = [call.args[0] for call in mock_update.call_args_list]
            assert any(u.get("payment_status") == "paid" for u in update_calls)
            assert any(u.get("status") == "paid" for u in update_calls) # session status

