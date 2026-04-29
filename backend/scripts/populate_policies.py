import os
import sys
import firebase_admin
from firebase_admin import credentials, firestore

# Ensure the script can find the app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from firebase_client import db

TERMS_OF_SERVICE = """# Terms of Service

**Last Updated:** April 2026

Welcome to Swipify! These Terms of Service ("Terms") govern your access to and use of the Swipify mobile application, website, and related services (collectively, the "Platform"). By creating an account or using the Platform, you agree to be bound by these Terms.

## 1. Using Swipify
You must be at least 18 years old to use the Platform. You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.

## 2. Buying and Selling
Swipify is a marketplace that allows users to buy and sell items. 
* **Buyers:** You agree to pay for items you purchase, including any applicable shipping fees and taxes.
* **Sellers:** You agree to provide accurate descriptions of your items, ship items promptly after payment, and resolve disputes in good faith. You are responsible for complying with all applicable laws regarding the items you sell.

## 3. Prohibited Conduct
You agree not to:
* Violate any laws or regulations.
* Sell prohibited, illegal, or counterfeit items.
* Engage in fraudulent or deceptive practices.
* Harass, threaten, or abuse other users.
* Interfere with the operation of the Platform.

## 4. Fees and Payments
Swipify may charge fees for certain services, such as listing or selling items. All fees are non-refundable unless otherwise stated. We use third-party payment processors, and you agree to their terms of service.

## 5. Intellectual Property
The Platform and its content are protected by copyright, trademark, and other intellectual property laws. You may not use our intellectual property without our written consent.

## 6. Termination
We may suspend or terminate your account at any time, for any reason, without notice.

## 7. Disclaimers and Limitation of Liability
The Platform is provided "as is" and without warranties of any kind. Swipify is not responsible for the actions of its users or the quality of the items sold on the Platform. Our liability is limited to the fullest extent permitted by law.

## 8. Dispute Resolution
Any disputes arising out of these Terms or your use of the Platform will be resolved through binding arbitration.

## 9. Changes to these Terms
We may update these Terms from time to time. We will notify you of any material changes by posting the new Terms on the Platform.
"""

PRIVACY_POLICY = """# Privacy Policy

**Last Updated:** April 2026

At Swipify, we take your privacy seriously. This Privacy Policy explains how we collect, use, and share your personal information when you use our Platform.

## 1. Information We Collect
We collect information you provide to us directly, such as when you create an account, update your profile, list an item, or communicate with other users. This may include:
* **Account Information:** Name, email address, phone number, date of birth, and password.
* **Transaction Information:** Payment details, shipping address, and purchase history.
* **Content:** Messages, photos, and item descriptions.

We also collect information automatically when you use the Platform, such as your IP address, device information, and browsing activity.

## 2. How We Use Your Information
We use your information to:
* Provide, maintain, and improve the Platform.
* Process transactions and send related information.
* Communicate with you about products, services, offers, and events.
* Personalize your experience on the Platform.
* Detect, investigate, and prevent fraudulent or illegal activities.

## 3. How We Share Your Information
We may share your information with:
* **Other Users:** Information you share publicly, such as your profile and listings, is visible to other users.
* **Service Providers:** We use third-party service providers to help us operate the Platform, such as payment processors and cloud hosting providers.
* **Law Enforcement:** We may disclose your information if required by law or to protect our rights or the rights of others.

## 4. Your Choices
You can access and update your account information at any time. You can also opt out of receiving promotional communications from us.

## 5. Data Security
We take reasonable measures to protect your information from unauthorized access, use, or disclosure. However, no method of transmission over the Internet or electronic storage is 100% secure.

## 6. Children's Privacy
The Platform is not intended for children under 18. We do not knowingly collect personal information from children under 18.

## 7. Changes to this Privacy Policy
We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new Privacy Policy on the Platform.

## 8. Contact Us
If you have any questions about this Privacy Policy, please contact us at privacy@swipify.com.
"""

def main():
    doc_ref = db.collection('settings').document('signup_config')
    
    # Check if doc exists, if so merge, otherwise create
    doc = doc_ref.get()
    
    data_to_update = {
        'terms_of_service': TERMS_OF_SERVICE,
        'privacy_policy': PRIVACY_POLICY
    }
    
    if doc.exists:
        doc_ref.update(data_to_update)
        print("Successfully updated existing signup_config with new Terms and Privacy Policy.")
    else:
        # Provide base structure if it doesn't exist
        base_data = {
            'genders': ['Male', 'Female', 'Non-Binary', 'Prefer not to say'],
            'password_rules': {
                'min_length': 8,
                'require_number': True,
                'require_special': True
            }
        }
        base_data.update(data_to_update)
        doc_ref.set(base_data)
        print("Successfully created new signup_config with Terms and Privacy Policy.")

if __name__ == '__main__':
    main()
