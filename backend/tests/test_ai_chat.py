# tests/test_ai_chat.py
# Tests for the AI Chat route and service.

import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient


@pytest.fixture
def client():
    """Create a test client with mocked Firebase."""
    with patch("firebase_client.db"):
        with patch("firebase_admin.credentials.Certificate"):
            with patch("firebase_admin.initialize_app"):
                from main import app
                return TestClient(app)


class TestAiChatRoute:
    """Tests for POST /ai/chat endpoint."""

    def test_missing_user_id(self, client):
        """Should return 422 when user_id is missing."""
        response = client.post("/ai/chat", json={"message": "hello"})
        assert response.status_code == 422

    def test_missing_message(self, client):
        """Should return 422 when message is missing."""
        response = client.post("/ai/chat", json={"user_id": "test123"})
        assert response.status_code == 422

    def test_message_too_long(self, client):
        """Should return 400 when message exceeds 2000 chars."""
        response = client.post("/ai/chat", json={
            "user_id": "test123",
            "message": "x" * 2001,
        })
        assert response.status_code == 400

    @patch("app.services.ai_chat_service.chat_with_ai")
    def test_successful_chat(self, mock_chat, client):
        """Should return AI reply on success."""
        mock_chat.return_value = {
            "reply": "I can help with that!",
            "ticket_id": None,
        }
        response = client.post("/ai/chat", json={
            "user_id": "test123",
            "message": "Where is my order?",
        })
        assert response.status_code == 200
        data = response.json()
        assert "reply" in data
        assert data["ticket_id"] is None

    @patch("app.services.ai_chat_service.chat_with_ai")
    def test_chat_with_ticket_creation(self, mock_chat, client):
        """Should return ticket_id when AI creates a ticket."""
        mock_chat.return_value = {
            "reply": "Your ticket has been created!",
            "ticket_id": "abc12345-test",
        }
        response = client.post("/ai/chat", json={
            "user_id": "test123",
            "message": "Yes, create a ticket for my refund issue",
        })
        assert response.status_code == 200
        data = response.json()
        assert data["ticket_id"] == "abc12345-test"


class TestAiChatService:
    """Unit tests for AI chat service functions."""

    def test_parse_ticket_from_response_valid(self):
        """Should parse valid ticket block."""
        from app.services.ai_chat_service import _parse_ticket_from_response

        response = """Sure, I'll create that for you.
[TICKET_CREATE]
category: Refunds & Returns
subject: Refund for damaged item
message: User received a damaged product and wants a full refund.
[/TICKET_CREATE]"""

        result = _parse_ticket_from_response(response)
        assert result is not None
        assert result["category"] == "Refunds & Returns"
        assert result["subject"] == "Refund for damaged item"

    def test_parse_ticket_from_response_no_block(self):
        """Should return None when no ticket block present."""
        from app.services.ai_chat_service import _parse_ticket_from_response

        result = _parse_ticket_from_response("Just a normal AI response.")
        assert result is None

    def test_determine_priority(self):
        """Should map categories to correct priorities."""
        from app.services.ai_chat_service import _determine_priority

        assert _determine_priority("Refunds & Returns") == "high"
        assert _determine_priority("Account & Verification") == "urgent"
        assert _determine_priority("Others") == "medium"
