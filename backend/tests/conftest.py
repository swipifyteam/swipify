import pytest
from fastapi.testclient import TestClient
from unittest.mock import MagicMock, patch
import sys
import os

# Add the backend directory to sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

@pytest.fixture
def mock_firebase_auth():
    with patch("firebase_admin.auth.verify_id_token") as mock:
        yield mock

@pytest.fixture
def mock_db():
    with patch("firebase_client.db") as mock:
        yield mock

@pytest.fixture
def client():
    from main import app
    return TestClient(app)
