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
    """Patch db in all modules that import it directly via `from firebase_client import db`."""
    mock = MagicMock()
    with patch("firebase_client.db", mock), \
         patch("app.utils.auth_utils.db", mock), \
         patch("app.routes.admin.db", mock):
        yield mock

@pytest.fixture
def client():
    from main import app
    return TestClient(app)

