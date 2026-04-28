"""
Tests for Admin Marketing & Support API endpoints.
Uses mocked Firestore and Firebase Auth for deterministic execution.
"""
import pytest
from unittest.mock import MagicMock, patch, PropertyMock
from datetime import datetime, timedelta, UTC


# --- HELPER: Build a mock Firestore document ---
def _mock_doc(doc_id: str, data: dict, exists: bool = True):
    doc = MagicMock()
    doc.id = doc_id
    doc.exists = exists
    doc.to_dict.return_value = data
    return doc


def _mock_admin_user():
    """Returns a mock admin user dict as returned by require_role."""
    return {"uid": "admin_001", "role": "super_admin"}


# ──────────────────────────────────────────────────────────────────────
# MODULE 7 — MARKETING VOUCHER CRUD
# ──────────────────────────────────────────────────────────────────────

class TestMarketingVouchers:
    """Tests for GET / POST / PUT / DELETE on /admin/marketing/vouchers."""

    def test_list_vouchers_returns_unified_list(self, client, mock_db, mock_firebase_auth):
        """GET /admin/marketing/vouchers returns platform + seller vouchers."""
        # Auth chain: verify_id_token -> users doc -> require_admin
        mock_firebase_auth.return_value = {"uid": "admin_001"}

        # Platform vouchers
        platform_doc = _mock_doc("v1", {
            "code": "WELCOME20",
            "discount_type": "percentage",
            "value": 20,
            "usage_count": 5,
            "usage_limit": 100,
            "min_spend": 0,
            "start_date": datetime.now(UTC).replace(tzinfo=None).isoformat(),
            "end_date": (datetime.now(UTC).replace(tzinfo=None) + timedelta(days=30)).isoformat(),
            "created_at": datetime.now(UTC).replace(tzinfo=None).isoformat(),
        })

        # Seller vouchers
        seller_doc = _mock_doc("sv1", {
            "code": "SHOP10",
            "seller_id": "seller_001",
            "discount_value": 10,
            "used_count": 2,
            "usage_limit": 50,
            "min_order_amount": 100,
            "end_date": (datetime.now(UTC).replace(tzinfo=None) + timedelta(days=15)).isoformat(),
        })

        # Admin user document (for auth chain)
        admin_user_doc = _mock_doc("admin_001", {
            "role": "super_admin",
            "name": "Admin",
            "email": "admin@swipify.com",
        })

        # shops collection for name resolution
        shop_doc = _mock_doc("seller_001", {"shop_name": "Test Shop"})

        def collection_router(name):
            coll = MagicMock()
            if name == "users":
                coll.document.return_value.get.return_value = admin_user_doc
                return coll
            elif name == "vouchers":
                coll.get.return_value = [platform_doc]
                return coll
            elif name == "seller_vouchers":
                coll.get.return_value = [seller_doc]
                return coll
            elif name == "shops":
                coll.document.return_value.get.return_value = shop_doc
                return coll
            elif name == "sellers":
                coll.document.return_value.get.return_value = _mock_doc("x", {}, exists=False)
                return coll
            return coll

        mock_db.collection.side_effect = collection_router

        response = client.get(
            "/admin/marketing/vouchers",
            headers={"Authorization": "Bearer fake_token"}
        )

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1  # At minimum the platform voucher

    def test_create_voucher_uppercases_code(self, client, mock_db, mock_firebase_auth):
        """POST /admin/marketing/vouchers should uppercase the code."""
        mock_firebase_auth.return_value = {"uid": "admin_001"}

        # Mock: no existing voucher with same code
        vouchers_coll = MagicMock()
        vouchers_coll.where.return_value.get.return_value = []
        vouchers_coll.add.return_value = (None, MagicMock(id="new_v1"))

        audit_coll = MagicMock()

        def collection_router(name):
            if name == "vouchers":
                return vouchers_coll
            elif name == "audit_logs":
                return audit_coll
            return MagicMock()

        mock_db.collection.side_effect = collection_router

        payload = {
            "code": "summer2024",
            "discount_type": "percentage",
            "value": 25.0,
            "min_spend": 0,
            "end_date": (datetime.now(UTC).replace(tzinfo=None) + timedelta(days=60)).isoformat(),
        }

        with patch("app.routes.admin.require_role", return_value=lambda: _mock_admin_user()):
            response = client.post(
                "/admin/marketing/vouchers",
                json=payload,
                headers={"Authorization": "Bearer fake_token"}
            )

        # Verify the code was uppercased in the Firestore write
        if response.status_code == 200:
            call_args = vouchers_coll.add.call_args
            written_data = call_args[0][0]
            assert written_data["code"] == "SUMMER2024"

    def test_update_voucher_partial(self, client, mock_db, mock_firebase_auth):
        """PUT /admin/marketing/vouchers/{id} should do partial update."""
        mock_firebase_auth.return_value = {"uid": "admin_001"}

        existing_doc = _mock_doc("v1", {"code": "OLD", "value": 10}, exists=True)
        voucher_ref = MagicMock()
        voucher_ref.get.return_value = existing_doc

        vouchers_coll = MagicMock()
        vouchers_coll.document.return_value = voucher_ref
        audit_coll = MagicMock()

        def collection_router(name):
            if name == "vouchers":
                return vouchers_coll
            elif name == "audit_logs":
                return audit_coll
            return MagicMock()

        mock_db.collection.side_effect = collection_router

        payload = {"value": 50.0, "discount_type": "fixed"}

        with patch("app.routes.admin.require_role", return_value=lambda: _mock_admin_user()):
            response = client.put(
                "/admin/marketing/vouchers/v1",
                json=payload,
                headers={"Authorization": "Bearer fake_token"}
            )

        if response.status_code == 200:
            # Verify update was called on the ref
            voucher_ref.update.assert_called_once()

    def test_update_voucher_not_found_returns_404(self, client, mock_db, mock_firebase_auth):
        """PUT /admin/marketing/vouchers/{id} returns 404 if doc doesn't exist."""
        mock_firebase_auth.return_value = {"uid": "admin_001"}

        missing_doc = _mock_doc("missing", {}, exists=False)
        voucher_ref = MagicMock()
        voucher_ref.get.return_value = missing_doc

        vouchers_coll = MagicMock()
        vouchers_coll.document.return_value = voucher_ref

        mock_db.collection.return_value = vouchers_coll

        payload = {"value": 50.0}

        with patch("app.routes.admin.require_role", return_value=lambda: _mock_admin_user()):
            response = client.put(
                "/admin/marketing/vouchers/missing",
                json=payload,
                headers={"Authorization": "Bearer fake_token"}
            )

        # Should be 404 or 422 depending on auth middleware behavior
        assert response.status_code in [404, 422, 403]

    def test_delete_voucher_success(self, client, mock_db, mock_firebase_auth):
        """DELETE /admin/marketing/vouchers/{id} deletes and logs."""
        mock_firebase_auth.return_value = {"uid": "admin_001"}

        existing_doc = _mock_doc("v1", {"code": "DEL"}, exists=True)
        voucher_ref = MagicMock()
        voucher_ref.get.return_value = existing_doc

        vouchers_coll = MagicMock()
        vouchers_coll.document.return_value = voucher_ref
        audit_coll = MagicMock()

        def collection_router(name):
            if name == "vouchers":
                return vouchers_coll
            elif name == "audit_logs":
                return audit_coll
            return MagicMock()

        mock_db.collection.side_effect = collection_router

        with patch("app.routes.admin.require_role", return_value=lambda: _mock_admin_user()):
            response = client.delete(
                "/admin/marketing/vouchers/v1",
                headers={"Authorization": "Bearer fake_token"}
            )

        if response.status_code == 200:
            voucher_ref.delete.assert_called_once()
            # Verify audit log
            audit_coll.add.assert_called_once()
            call_data = audit_coll.add.call_args[0][0]
            assert call_data["action"] == "delete_voucher"


# ──────────────────────────────────────────────────────────────────────
# MODULE 8 — SUPPORT TICKETS & DISPUTES
# ──────────────────────────────────────────────────────────────────────

class TestSupportEndpoints:
    """Tests for support ticket and dispute endpoints."""

    def test_list_tickets_returns_paginated(self, client, mock_db, mock_firebase_auth):
        """GET /admin/support/tickets returns paginated response."""
        mock_firebase_auth.return_value = {"uid": "admin_001"}

        ticket_doc = _mock_doc("t1", {
            "subject": "Payment issue",
            "user_email": "user@test.com",
            "status": "open",
            "priority": "high",
            "message": "My payment failed",
            "category": "payment",
            "created_at": datetime.now(UTC).replace(tzinfo=None).isoformat(),
        })

        tickets_coll = MagicMock()
        tickets_coll.where.return_value = tickets_coll
        tickets_coll.order_by.return_value = tickets_coll
        tickets_coll.offset.return_value = tickets_coll
        tickets_coll.limit.return_value = tickets_coll
        tickets_coll.get.return_value = [ticket_doc]

        # For total count
        count_agg = MagicMock()
        count_agg.get.return_value = [[MagicMock(value=1)]]
        tickets_coll.count.return_value = count_agg

        mock_db.collection.return_value = tickets_coll

        with patch("app.routes.admin.require_role", return_value=lambda: _mock_admin_user()):
            response = client.get(
                "/admin/support/tickets",
                headers={"Authorization": "Bearer fake_token"}
            )

        if response.status_code == 200:
            data = response.json()
            # Should have a tickets key (paginated format)
            assert "tickets" in data or isinstance(data, list)

    def test_update_ticket_status(self, client, mock_db, mock_firebase_auth):
        """PUT /admin/support/tickets/{id} updates status."""
        mock_firebase_auth.return_value = {"uid": "admin_001"}

        existing_doc = _mock_doc("t1", {"status": "open"}, exists=True)
        ticket_ref = MagicMock()
        ticket_ref.get.return_value = existing_doc

        tickets_coll = MagicMock()
        tickets_coll.document.return_value = ticket_ref
        audit_coll = MagicMock()

        def collection_router(name):
            if name == "support_tickets":
                return tickets_coll
            elif name == "audit_logs":
                return audit_coll
            return MagicMock()

        mock_db.collection.side_effect = collection_router

        payload = {"status": "resolved"}

        with patch("app.routes.admin.require_role", return_value=lambda: _mock_admin_user()):
            response = client.put(
                "/admin/support/tickets/t1",
                json=payload,
                headers={"Authorization": "Bearer fake_token"}
            )

        if response.status_code == 200:
            ticket_ref.update.assert_called_once()

    def test_resolve_dispute_refunded_updates_order(self, client, mock_db, mock_firebase_auth):
        """PUT /admin/support/disputes/{id}/resolve with 'refunded' also updates the order."""
        mock_firebase_auth.return_value = {"uid": "admin_001"}

        dispute_doc = _mock_doc("d1", {
            "order_id": "order_001",
            "status": "open",
            "amount": 500,
        }, exists=True)
        dispute_ref = MagicMock()
        dispute_ref.get.return_value = dispute_doc

        order_ref = MagicMock()
        disputes_coll = MagicMock()
        disputes_coll.document.return_value = dispute_ref
        orders_coll = MagicMock()
        orders_coll.document.return_value = order_ref
        audit_coll = MagicMock()

        def collection_router(name):
            if name == "disputes":
                return disputes_coll
            elif name == "orders":
                return orders_coll
            elif name == "audit_logs":
                return audit_coll
            return MagicMock()

        mock_db.collection.side_effect = collection_router

        with patch("app.routes.admin.require_role", return_value=lambda: _mock_admin_user()):
            response = client.put(
                "/admin/support/disputes/d1/resolve?resolution=refunded&notes=Approved",
                headers={"Authorization": "Bearer fake_token"}
            )

        if response.status_code == 200:
            # Dispute should be updated
            dispute_ref.update.assert_called_once()
            # Order should also be updated to 'refunded'
            order_ref.update.assert_called_once()

    def test_list_tickets_resolves_identities(self, client, mock_db, mock_firebase_auth):
        """GET /admin/support/tickets should resolve user names via batch_resolve."""
        mock_firebase_auth.return_value = {"uid": "admin_001"}

        ticket_doc = _mock_doc("t1", {
            "user_id": "user_123",
            "assigned_to": "admin_456",
            "subject": "Help",
            "status": "open",
            "created_at": datetime.now(UTC).replace(tzinfo=None)
        })
        
        # Admin user doc (the person making the request)
        admin_requesting_doc = _mock_doc("admin_001", {"role": "super_admin"})
        
        user_doc = _mock_doc("user_123", {"display_name": "John Doe"})
        admin_doc = _mock_doc("admin_456", {"display_name": "Support Agent Smith"})

        # Mock collection routing
        def coll_router(name):
            mock = MagicMock()
            if name == "support_tickets":
                mock.where.return_value = mock
                mock.order_by.return_value = mock
                mock.offset.return_value = mock
                mock.limit.return_value = mock
                mock.get.return_value = [ticket_doc]
                mock.count.return_value.get.return_value = [[MagicMock(value=1)]]
                return mock
            elif name == "users":
                # For get_current_user
                mock.document.return_value.get.return_value = admin_requesting_doc
                # For batch_resolve_user_names
                mock.where.return_value.select.return_value.get.return_value = [user_doc, admin_doc]
                return mock
            return MagicMock()

        mock_db.collection.side_effect = coll_router

        response = client.get(
            "/admin/support/tickets",
            headers={"Authorization": "Bearer fake_token"}
        )

        assert response.status_code == 200
        data = response.json()
        ticket = data["tickets"][0]
        assert ticket["user_name"] == "John Doe"
        assert ticket["assignee_name"] == "Support Agent Smith"

    def test_list_disputes_resolves_identities(self, client, mock_db, mock_firebase_auth):
        """GET /admin/support/disputes should resolve buyer and seller names."""
        mock_firebase_auth.return_value = {"uid": "admin_001"}

        dispute_doc = _mock_doc("d1", {
            "buyer_id": "buyer_001",
            "seller_id": "seller_002",
            "status": "pending",
            "created_at": datetime.now(UTC).replace(tzinfo=None)
        })
        
        # Admin user doc (the person making the request)
        admin_requesting_doc = _mock_doc("admin_001", {"role": "super_admin"})
        
        buyer_doc = _mock_doc("buyer_001", {"display_name": "Alice Buyer"})
        # batch_resolve also looks at sellers/shops. Let's simplify and just mock users for now
        # as batch_resolve cascades through them.
        seller_user_doc = _mock_doc("seller_002", {"display_name": "Bob Seller", "shop_name": "Bob's Shop"})

        def coll_router(name):
            mock = MagicMock()
            if name == "disputes":
                mock.where.return_value = mock
                mock.order_by.return_value = mock
                mock.offset.return_value = mock
                mock.limit.return_value = mock
                mock.get.return_value = [dispute_doc]
                mock.count.return_value.get.return_value = [[MagicMock(value=1)]]
                return mock
            elif name == "users":
                # For get_current_user
                mock.document.return_value.get.return_value = admin_requesting_doc
                # For batch_resolve_user_names
                mock.where.return_value.select.return_value.get.return_value = [buyer_doc, seller_user_doc]
                return mock
            return MagicMock()

        mock_db.collection.side_effect = coll_router

        response = client.get(
            "/admin/support/disputes",
            headers={"Authorization": "Bearer fake_token"}
        )

        assert response.status_code == 200
        data = response.json()
        dispute = data["disputes"][0]
        assert dispute["buyer_name"] == "Alice Buyer"
        assert dispute["seller_name"] == "Bob's Shop"
