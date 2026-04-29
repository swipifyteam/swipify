import pytest
from unittest.mock import MagicMock, patch, PropertyMock
from datetime import datetime, UTC, timedelta
from app.services.admin_stats_service import AdminStatsService

# --- HELPER: Build a mock Firestore document ---
def _mock_doc(doc_id: str, data: dict, exists: bool = True):
    doc = MagicMock()
    doc.id = doc_id
    doc.exists = exists
    doc.to_dict.return_value = data
    return doc

# --- HELPER: Build a mock count result ---
def _mock_count(value: int):
    mock_val = MagicMock()
    mock_val.value = value
    return [[mock_val]]

@pytest.mark.asyncio
async def test_get_dashboard_stats_cache_valid():
    """Verify that cached stats are returned if not stale."""
    now = datetime.now(UTC).replace(tzinfo=None)
    cached_data = {
        "last_updated": now - timedelta(minutes=10),
        "total_users": 100,
        "gmv": 5000.0
    }
    
    mock_doc = _mock_doc("dashboard_stats", cached_data)
    
    with patch("firebase_client.db.collection") as mock_coll:
        mock_coll.return_value.document.return_value.get.return_value = mock_doc
        
        stats = await AdminStatsService.get_dashboard_stats()
        
        assert stats["total_users"] == 100
        assert stats["gmv"] == 5000.0
        # Should not have recomputed (mock_coll.return_value.get should not be called for other collections)
        assert mock_coll.call_count == 1 

@pytest.mark.asyncio
async def test_get_dashboard_stats_recompute():
    """Verify that stats are recomputed if cache is missing or stale."""
    with patch("firebase_client.db.collection") as mock_coll:
        # Cache doesn't exist
        mock_coll.return_value.document.return_value.get.return_value = _mock_doc("stats", {}, exists=False)
        
        # Mock various collection counts/streams
        def side_effect(name):
            m = MagicMock()
            # Handle get_count: results = query.count().get() -> results[0][0].value
            m.count.return_value.get.return_value = _mock_count(5) 
            m.where.return_value.count.return_value.get.return_value = _mock_count(2)
            m.select.return_value.stream.return_value = []
            m.get.return_value = []
            return m
            
        mock_coll.side_effect = side_effect
        
        stats = await AdminStatsService.get_dashboard_stats()
        
        assert stats["total_users"] == 5
        assert stats["total_disputes"] == 5
        assert stats["active_listings"] == 2
        assert stats["active_campaigns"] == 0

@pytest.mark.asyncio
async def test_marketing_stats_calculation():
    """Verify active marketing campaign count logic."""
    now = datetime.now(UTC).replace(tzinfo=None)
    
    # One active, one expired
    platform_vouchers = [
        _mock_doc("v1", {"code": "ACTIVE", "end_date": (now + timedelta(days=1)).isoformat()}),
        _mock_doc("v2", {"code": "EXPIRED", "end_date": (now - timedelta(days=1)).isoformat()})
    ]
    
    seller_vouchers = [
        _mock_doc("s1", {"code": "SELLER_ACTIVE", "end_date": (now + timedelta(days=1)).isoformat()})
    ]
    
    with patch("firebase_client.db.collection") as mock_coll:
        def side_effect(name):
            mock = MagicMock()
            if name == "vouchers":
                mock.get.return_value = platform_vouchers
            elif name == "seller_vouchers":
                mock.get.return_value = seller_vouchers
            else:
                mock.get.return_value = []
                mock.count.return_value.get.return_value = _mock_count(0)
                mock.where.return_value.count.return_value.get.return_value = _mock_count(0)
                mock.select.return_value.stream.return_value = []
            return mock
            
        mock_coll.side_effect = side_effect
        mock_coll.return_value.document.return_value.get.return_value = _mock_doc("stats", {}, exists=False)

        stats = await AdminStatsService.get_dashboard_stats()
        
        # Active: platform v1 + seller s1 = 2
        assert stats["active_campaigns"] == 2
