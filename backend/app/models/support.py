from pydantic import BaseModel, Field
from typing import Optional, List, Any
from datetime import datetime

class SupportTicketResponse(BaseModel):
    id: str
    user_id: str
    user_email: str
    subject: str
    message: str
    status: str  # "open", "in_progress", "resolved", "closed"
    priority: str # "low", "medium", "high", "urgent"
    category: str # "general", "billing", "technical", "account", "dispute"
    order_id: Optional[str] = None
    assigned_to: Optional[str] = None
    created_at: Any
    updated_at: Any

class DisputeResponse(BaseModel):
    id: str
    order_id: str
    buyer_id: str
    seller_id: str
    reason: str
    amount: float
    status: str # "pending", "under_review", "resolved_refunded", "resolved_rejected"
    evidence_urls: List[str] = []
    admin_notes: Optional[str] = None
    created_at: Any
    updated_at: Any

class SupportActionRequest(BaseModel):
    status: Optional[str] = None
    admin_notes: Optional[str] = None
    assigned_to: Optional[str] = None
