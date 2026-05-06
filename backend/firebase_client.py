# firebase_client.py
# Shared Firebase Admin SDK initialization and Firestore client.
# Import `db` from this module in all routers and services.

import firebase_admin
from firebase_admin import credentials, firestore
import os
import json

# Initialize Firebase Admin SDK only once
if not firebase_admin._apps:
    service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT")
    
    if service_account_json:
        # Load from environment variable (for Render/Production)
        service_account_info = json.loads(service_account_json)
        cred = credentials.Certificate(service_account_info)
    else:
        # Fallback to local file (for Development)
        cred = credentials.Certificate(
            os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")
        )
        
    firebase_admin.initialize_app(cred)

# Shared Firestore client — use this in all routers
db = firestore.client()

