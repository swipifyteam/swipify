"""
Tests for the Reviews API endpoints.
TDD: Written BEFORE implementation changes.
"""
import pytest
from fastapi.testclient import TestClient
from unittest.mock import MagicMock, patch
from datetime import datetime


@pytest.fixture
def mock_reviews_db():
    """Patch db in the reviews route module."""
    mock = MagicMock()
    with patch("app.routes.reviews.db", mock):
        yield mock


@pytest.fixture
def client():
    from main import app
    return TestClient(app)


def _setup_ordered_query(mock_db, docs):
    """Helper: configure mock so ordered query succeeds."""
    query_mock = MagicMock()
    query_mock.order_by.return_value = query_mock
    query_mock.get.return_value = docs
    mock_db.collection.return_value.where.return_value = query_mock
    return query_mock


# ── GET /reviews/product/{product_id} ──────────────────────────────────────

class TestGetProductReviews:
    """Tests for GET /reviews/product/{product_id}"""

    def test_returns_empty_list_when_no_reviews(self, client, mock_reviews_db):
        """Should return empty list for a product with no reviews."""
        _setup_ordered_query(mock_reviews_db, [])
        response = client.get("/reviews/product/prod_123")
        assert response.status_code == 200
        assert response.json() == []

    def test_returns_reviews_for_product(self, client, mock_reviews_db):
        """Should return review list filtered by product_id."""
        mock_doc = MagicMock()
        mock_doc.to_dict.return_value = {
            "id": "rev_001",
            "user_id": "user_abc",
            "user_name": "John Doe",
            "product_id": "prod_123",
            "order_id": "ord_001",
            "rating": 5,
            "comment": "Great product!",
            "image_urls": ["https://img.example.com/1.jpg"],
            "created_at": datetime(2026, 5, 1, 12, 0, 0),
        }
        _setup_ordered_query(mock_reviews_db, [mock_doc])

        response = client.get("/reviews/product/prod_123")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["user_name"] == "John Doe"
        assert data[0]["rating"] == 5
        assert data[0]["comment"] == "Great product!"
        assert len(data[0]["image_urls"]) == 1

    def test_orders_by_created_at_desc(self, client, mock_reviews_db):
        """Should attempt to order results by created_at descending."""
        query_mock = _setup_ordered_query(mock_reviews_db, [])
        client.get("/reviews/product/prod_123")
        query_mock.order_by.assert_called_once()
        args, kwargs = query_mock.order_by.call_args
        assert args[0] == "created_at"

    def test_respects_limit_via_slicing(self, client, mock_reviews_db):
        """Should limit results via slicing."""
        # Create 10 mock docs
        docs = []
        for i in range(10):
            d = MagicMock()
            d.to_dict.return_value = {
                "id": f"rev_{i}", "user_id": "u", "user_name": "X",
                "product_id": "p", "order_id": "o", "rating": 5,
                "comment": "ok", "image_urls": [],
                "created_at": f"2026-05-0{min(i+1,9)}T00:00:00",
            }
            docs.append(d)
        _setup_ordered_query(mock_reviews_db, docs)

        response = client.get("/reviews/product/p?limit=3")
        assert response.status_code == 200
        assert len(response.json()) == 3

    def test_respects_offset_via_slicing(self, client, mock_reviews_db):
        """Should offset results via slicing."""
        docs = []
        for i in range(5):
            d = MagicMock()
            d.to_dict.return_value = {
                "id": f"rev_{i}", "user_id": "u", "user_name": "X",
                "product_id": "p", "order_id": "o", "rating": 5,
                "comment": "ok", "image_urls": [],
                "created_at": f"2026-05-0{i+1}T00:00:00",
            }
            docs.append(d)
        _setup_ordered_query(mock_reviews_db, docs)

        response = client.get("/reviews/product/p?offset=3&limit=10")
        assert response.status_code == 200
        assert len(response.json()) == 2  # 5 docs, offset 3 = 2 remaining

    def test_handles_string_created_at(self, client, mock_reviews_db):
        """Should handle created_at that is already a string."""
        mock_doc = MagicMock()
        mock_doc.to_dict.return_value = {
            "id": "rev_002", "user_id": "u", "user_name": "Jane",
            "product_id": "p", "order_id": "o", "rating": 4,
            "comment": "Good", "image_urls": [],
            "created_at": "2026-05-01T12:00:00",
        }
        _setup_ordered_query(mock_reviews_db, [mock_doc])

        response = client.get("/reviews/product/p")
        assert response.status_code == 200
        assert response.json()[0]["created_at"] == "2026-05-01T12:00:00"

    def test_fallback_when_index_missing(self, client, mock_reviews_db):
        """Should fallback to unordered query + Python sort when index is missing."""
        # Make order_by raise (simulating missing index)
        where_mock = MagicMock()
        order_mock = MagicMock()
        order_mock.get.side_effect = Exception("index missing")
        where_mock.order_by.return_value = order_mock

        # Fallback: unordered .get()
        mock_doc = MagicMock()
        mock_doc.to_dict.return_value = {
            "id": "rev_fb", "user_id": "u", "user_name": "Fallback",
            "product_id": "p", "order_id": "o", "rating": 3,
            "comment": "works", "image_urls": [],
            "created_at": "2026-05-01T00:00:00",
        }
        where_mock.get.return_value = [mock_doc]
        mock_reviews_db.collection.return_value.where.return_value = where_mock

        response = client.get("/reviews/product/p")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["user_name"] == "Fallback"


class TestCreateReviewUpdatesProduct:
    """Tests for POST /reviews — product average_rating + total_reviews update."""

    def test_updates_product_stats_on_review_creation(self, client, mock_reviews_db):
        """After creating a review, the product's average_rating and total_reviews should update."""
        order_doc = MagicMock()
        order_doc.exists = True
        order_doc.to_dict.return_value = {"user_id": "user_abc"}

        user_doc = MagicMock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {"full_name": "John Doe"}

        existing_query = MagicMock()
        existing_query.get.return_value = []

        existing_review_doc = MagicMock()
        existing_review_doc.to_dict.return_value = {"rating": 4}
        all_reviews_query = MagicMock()
        all_reviews_query.get.return_value = [existing_review_doc]

        product_ref = MagicMock()

        def collection_router(name):
            mock_coll = MagicMock()
            if name == "orders":
                mock_coll.document.return_value.get.return_value = order_doc
            elif name == "users":
                mock_coll.document.return_value.get.return_value = user_doc
            elif name == "reviews":
                def where_router(*args, **kwargs):
                    if len(args) >= 3 and args[0] == "order_id":
                        result = MagicMock()
                        result.where.return_value = existing_query
                        return result
                    elif len(args) >= 3 and args[0] == "product_id":
                        return all_reviews_query
                    return existing_query
                mock_coll.where = where_router
                mock_coll.document.return_value.set.return_value = None
            elif name == "products":
                mock_coll.document.return_value = product_ref
            return mock_coll

        mock_reviews_db.collection.side_effect = collection_router

        response = client.post("/reviews", json={
            "user_id": "user_abc",
            "product_id": "prod_123",
            "order_id": "ord_001",
            "rating": 5,
            "comment": "Excellent!",
            "image_urls": [],
        })

        assert response.status_code == 200
        product_ref.update.assert_called_once()
        update_args = product_ref.update.call_args[0][0]
        assert "average_rating" in update_args
        assert "total_reviews" in update_args
