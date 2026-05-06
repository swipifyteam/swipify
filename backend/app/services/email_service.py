import os
import random
import time
from typing import List, Optional
from fastapi_mail import ConnectionConfig, FastMail, MessageSchema, MessageType
from pydantic import EmailStr
from app.config import get_settings
from firebase_client import db
from google.cloud.firestore_v1 import SERVER_TIMESTAMP

settings = get_settings()

conf = ConnectionConfig(
    MAIL_USERNAME=settings.SMTP_USER,
    MAIL_PASSWORD=settings.SMTP_PASSWORD,
    MAIL_FROM=settings.FROM_EMAIL,
    MAIL_PORT=settings.SMTP_PORT,
    MAIL_SERVER=settings.SMTP_HOST,
    MAIL_FROM_NAME=settings.FROM_NAME,
    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True
)

class EmailService:
    def __init__(self):
        self.fm = FastMail(conf)

    async def send_email(self, recipient: str, subject: str, body: str, is_html: bool = True):
        """Sends an email using FastAPI-Mail."""
        try:
            if not settings.SMTP_USER or not settings.SMTP_PASSWORD:
                print(f"[EMAIL ERROR] SMTP credentials not configured. Skipping email to {recipient}")
                return False

            message = MessageSchema(
                subject=subject,
                recipients=[recipient],
                body=body,
                subtype=MessageType.html if is_html else MessageType.plain
            )
            
            await self.fm.send_message(message)
            print(f"[EMAIL SENT] To: {recipient}, Subject: {subject}")
            return True
        except Exception as e:
            print(f"[EMAIL ERROR] Failed to send to {recipient}: {str(e)}")
            return False

    # --- OTP SYSTEM ---

    async def send_otp_email(self, user_id: str, email: str):
        """Generates, stores, and sends an OTP email."""
        otp = str(random.randint(100000, 999999))
        expires_at = time.time() + 300  # 5 minutes
        
        # Store in Firestore
        db.collection("otps_email").document(email).set({
            "user_id": user_id,
            "code": otp,
            "expires_at": expires_at,
            "verified": False,
            "created_at": SERVER_TIMESTAMP
        })

        subject = "Your Swipify Verification Code"
        body = f"""
        <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 40px; background-color: #f8fafc; color: #1e293b;">
            <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);">
                <div style="background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); padding: 30px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: 700;">Verification Code</h1>
                </div>
                <div style="padding: 40px; text-align: center;">
                    <p style="font-size: 16px; line-height: 1.6; color: #475569; margin-bottom: 24px;">Your Swipify verification code is ready. Use it to complete your sign-in.</p>
                    <div style="background-color: #f1f5f9; border-radius: 12px; padding: 20px; display: inline-block;">
                        <span style="font-size: 36px; font-weight: 800; color: #2563eb; letter-spacing: 8px; font-family: monospace;">{otp}</span>
                    </div>
                    <p style="font-size: 14px; color: #94a3b8; margin-top: 24px;">This code will expire in <span style="color: #ef4444; font-weight: 600;">5 minutes</span>.</p>
                </div>
                <div style="padding: 20px; background-color: #f8fafc; border-top: 1px solid #e2e8f0; text-align: center;">
                    <p style="font-size: 12px; color: #94a3b8; margin: 0;">&copy; 2026 Swipify. All rights reserved.</p>
                </div>
            </div>
        </div>
        """
        return await self.send_email(email, subject, body)

    # --- ORDER NOTIFICATIONS ---

    async def send_order_status_email(self, recipient: str, order_id: str, status: str, tracking_number: Optional[str] = None):
        """Sends order status update emails."""
        status_map = {
            "processing": ("Your order is now being prepared", "Preparation Started"),
            "shipped": (f"Your order has been shipped. Track: {tracking_number or 'N/A'}", "Order Shipped 🚚"),
            "delivered": ("Your order has been delivered. Please leave a review!", "Delivered 🎉"),
        }

        if status.lower() not in status_map:
            return False

        message_text, subject_title = status_map[status.lower()]
        subject = f"{subject_title} - Swipify Order #{order_id[:8].upper()}"
        
        body = f"""
        <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 40px; background-color: #f8fafc; color: #1e293b;">
            <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);">
                <div style="background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); padding: 30px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: 700;">{subject_title}</h1>
                </div>
                <div style="padding: 40px;">
                    <p style="font-size: 18px; font-weight: 600; color: #1e293b; margin-bottom: 16px;">Hello,</p>
                    <p style="font-size: 16px; line-height: 1.6; color: #475569; margin-bottom: 24px;">{message_text}</p>
                    
                    <div style="background-color: #f1f5f9; border-radius: 12px; padding: 24px; margin-bottom: 24px;">
                        <p style="margin: 0 0 8px 0; font-size: 14px; color: #64748b;">Order Reference</p>
                        <p style="margin: 0; font-size: 18px; font-weight: 700; color: #1e293b;">#{order_id[:8].upper()}</p>
                        {f'<p style="margin: 16px 0 8px 0; font-size: 14px; color: #64748b;">Tracking Number</p><p style="margin: 0; font-size: 18px; font-weight: 700; color: #2563eb;">{tracking_number}</p>' if tracking_number else ''}
                    </div>

                    <a href="https://swipify.app/orders/{order_id}" style="display: inline-block; background-color: #2563eb; color: #ffffff; padding: 14px 28px; border-radius: 10px; text-decoration: none; font-weight: 600; font-size: 16px;">View Order Details</a>
                </div>
                <div style="padding: 20px; background-color: #f8fafc; border-top: 1px solid #e2e8f0; text-align: center;">
                    <p style="font-size: 12px; color: #94a3b8; margin: 0;">Thank you for shopping with Swipify!</p>
                </div>
            </div>
        </div>
        """
        return await self.send_email(recipient, subject, body)

    # --- SUPPORT TICKET ---

    async def send_support_ticket_email(self, recipient: str, ticket_id: str):
        """Sends support ticket confirmation email."""
        subject = f"Support Request Received - #{ticket_id[:8].upper()}"
        body = f"""
        <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 40px; background-color: #f8fafc; color: #1e293b;">
            <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);">
                <div style="background: linear-gradient(135deg, #10b981 0%, #059669 100%); padding: 30px; text-align: center;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: 700;">Request Received</h1>
                </div>
                <div style="padding: 40px;">
                    <p style="font-size: 18px; font-weight: 600; color: #1e293b; margin-bottom: 16px;">We're on it!</p>
                    <p style="font-size: 16px; line-height: 1.6; color: #475569; margin-bottom: 24px;">Your support request has been successfully received. Our dedicated team will review your message and get back to you as soon as possible.</p>
                    
                    <div style="background-color: #ecfdf5; border: 1px solid #d1fae5; border-radius: 12px; padding: 20px; text-align: center;">
                        <p style="margin: 0 0 4px 0; font-size: 14px; color: #065f46;">Ticket ID</p>
                        <p style="margin: 0; font-size: 24px; font-weight: 800; color: #047857; letter-spacing: 1px;">#{ticket_id[:8].upper()}</p>
                    </div>
                </div>
                <div style="padding: 20px; background-color: #f8fafc; border-top: 1px solid #e2e8f0; text-align: center;">
                    <p style="font-size: 12px; color: #94a3b8; margin: 0;">This is an automated message. No need to reply.</p>
                </div>
            </div>
        </div>
        """
        return await self.send_email(recipient, subject, body)

email_service = EmailService()
