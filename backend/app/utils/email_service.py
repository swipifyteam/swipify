# app/utils/email_service.py
# Email notification service for Swipify order status updates.
# Uses SMTP for sending transactional emails.
# Configure SMTP credentials via environment variables.

import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from firebase_client import db


# SMTP Configuration — set these in your environment or .env file
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
FROM_EMAIL = os.getenv("FROM_EMAIL", "noreply@swipify.app")
FROM_NAME = os.getenv("FROM_NAME", "Swipify")


def _get_user_email(user_id: str) -> str | None:
    """Fetch user email from Firestore users collection."""
    try:
        doc = db.collection("users").document(user_id).get()
        if doc.exists:
            return doc.to_dict().get("email")
    except Exception as e:
        print(f"[EMAIL] Failed to fetch user email: {e}")
    return None


def _build_shipped_html(order_id: str, tracking_number: str | None, provider: str | None) -> str:
    """Build HTML email body for order shipped notification."""
    tracking_section = ""
    if tracking_number:
        tracking_section = f"""
        <div style="background:#f0f4ff;padding:16px;border-radius:8px;margin:16px 0;">
            <p style="margin:0;font-size:14px;color:#555;">Tracking Number</p>
            <p style="margin:4px 0 0;font-size:20px;font-weight:700;color:#2563eb;letter-spacing:1px;">{tracking_number}</p>
            <p style="margin:4px 0 0;font-size:12px;color:#888;">Provider: {provider or 'Swipify Express'}</p>
        </div>
        """

    return f"""
    <div style="font-family:'Segoe UI',Arial,sans-serif;max-width:520px;margin:0 auto;padding:32px;">
        <div style="text-align:center;margin-bottom:24px;">
            <span style="font-size:48px;">🚚</span>
        </div>
        <h1 style="font-size:22px;color:#1a2332;text-align:center;margin-bottom:8px;">Your Order Has Been Shipped!</h1>
        <p style="text-align:center;color:#6b7a8d;font-size:14px;margin-bottom:24px;">
            Order <strong>#{order_id[:8].upper()}</strong> is on its way to you.
        </p>
        {tracking_section}
        <p style="color:#888;font-size:12px;text-align:center;margin-top:32px;">
            Thank you for shopping with Swipify!
        </p>
    </div>
    """


def _build_delivered_html(order_id: str) -> str:
    """Build HTML email body for order delivered notification."""
    return f"""
    <div style="font-family:'Segoe UI',Arial,sans-serif;max-width:520px;margin:0 auto;padding:32px;">
        <div style="text-align:center;margin-bottom:24px;">
            <span style="font-size:48px;">🎉</span>
        </div>
        <h1 style="font-size:22px;color:#1a2332;text-align:center;margin-bottom:8px;">Your Order Has Been Delivered!</h1>
        <p style="text-align:center;color:#6b7a8d;font-size:14px;margin-bottom:24px;">
            Order <strong>#{order_id[:8].upper()}</strong> has arrived. We hope you love it!
        </p>
        <div style="background:#f0fdf4;padding:16px;border-radius:8px;text-align:center;">
            <p style="margin:0;color:#27ae60;font-size:14px;font-weight:600;">
                ✅ Please confirm receipt in the app to complete your order.
            </p>
        </div>
        <p style="color:#888;font-size:12px;text-align:center;margin-top:32px;">
            Thank you for shopping with Swipify!
        </p>
    </div>
    """


def send_order_status_email(
    user_id: str,
    order_id: str,
    new_status: str,
    tracking_number: str | None = None,
    logistic_provider: str | None = None,
) -> bool:
    """Send an email notification for order status changes (shipped/delivered).
    
    Returns True if email was sent successfully, False otherwise.
    Silently fails — email should never block order processing.
    """
    # Only send for shipped and delivered
    if new_status not in ("shipped", "delivered"):
        return False

    # Guard: SMTP not configured
    if not SMTP_USER or not SMTP_PASSWORD:
        print(f"[EMAIL] SMTP not configured — skipping email for order {order_id}")
        return False

    recipient = _get_user_email(user_id)
    if not recipient:
        print(f"[EMAIL] No email found for user {user_id} — skipping")
        return False

    try:
        msg = MIMEMultipart("alternative")
        msg["From"] = f"{FROM_NAME} <{FROM_EMAIL}>"
        msg["To"] = recipient

        if new_status == "shipped":
            msg["Subject"] = f"Your Swipify Order #{order_id[:8].upper()} Has Been Shipped! 🚚"
            html = _build_shipped_html(order_id, tracking_number, logistic_provider)
        else:
            msg["Subject"] = f"Your Swipify Order #{order_id[:8].upper()} Has Been Delivered! 🎉"
            html = _build_delivered_html(order_id)

        msg.attach(MIMEText(html, "html"))

        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.ehlo()
            server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)

        print(f"[EMAIL] ✅ Sent {new_status} email to {recipient} for order {order_id[:8]}")
        return True

    except Exception as e:
        print(f"[EMAIL] ❌ Failed to send email: {e}")
        return False
