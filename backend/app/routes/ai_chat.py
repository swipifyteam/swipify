# app/routes/ai_chat.py
# AI Customer Support Chatbot route.
# POST /ai/chat — Sends user message to Gemini, returns AI response.
# DELETE /ai/chat/history/{user_id} — Clears chat history.

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from app.services.ai_chat_service import chat_with_ai, clear_chat_history
from app.utils.auth_utils import get_current_user, verify_owner

router = APIRouter()


class AIChatRequest(BaseModel):
    user_id: str
    message: str


class AIChatResponse(BaseModel):
    reply: str
    ticket_id: str | None = None


@router.post("/chat", response_model=AIChatResponse)
async def ai_chat(request: AIChatRequest, token: dict = Depends(get_current_user)):
    """Send a message to the Swipify AI Assistant and get a response."""
    print(f"[AI ROUTE] POST /ai/chat — user_id={request.user_id}")

    # [SECURITY FIX] Verify user is who they say they are
    verify_owner(request.user_id, token["uid"])

    if not request.user_id or not request.message:
        raise HTTPException(status_code=400, detail="user_id and message are required")

    if len(request.message) > 2000:
        raise HTTPException(status_code=400, detail="Message too long (max 2000 characters)")

    result = chat_with_ai(request.user_id, request.message)
    return AIChatResponse(reply=result["reply"], ticket_id=result.get("ticket_id"))


@router.delete("/chat/history/{user_id}")
async def delete_chat_history(user_id: str, token: dict = Depends(get_current_user)):
    """Clear AI chat history for a user."""
    print(f"[AI ROUTE] DELETE /ai/chat/history/{user_id}")

    # [SECURITY FIX] Verify owner
    verify_owner(user_id, token["uid"])

    success = clear_chat_history(user_id)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to clear chat history")
    return {"success": True, "message": "Chat history cleared"}
