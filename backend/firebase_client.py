# firebase_client.py
# Shared Firebase Admin SDK initialization and Firestore client.
# Import `db` from this module in all routers and services.

import firebase_admin
from firebase_admin import credentials, firestore
import os
import json

# Initialize Firebase Admin SDK only once
if not firebase_admin._apps:
    print("[DEBUG] firebase_client: Initializing Firebase Admin SDK...")
    service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT")
    
    if service_account_json:
        print("[DEBUG] firebase_client: Found FIREBASE_SERVICE_ACCOUNT env var")
        try:
            # Load from environment variable (for Render/Production)
            service_account_info = json.loads(service_account_json)
            cred = credentials.Certificate(service_account_info)
            print("[DEBUG] firebase_client: Successfully parsed service account JSON")
        except Exception as e:
            print(f"[DEBUG] firebase_client: FAILED to parse service account JSON: {e}")
            raise e
    else:
        print("[DEBUG] firebase_client: No env var found, falling back to local file")
        cred = credentials.Certificate(
            os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")
        )
        
    firebase_admin.initialize_app(cred)
    print("[DEBUG] firebase_client: Firebase Admin SDK initialized successfully")


# Shared Firestore client — use this in all routers
db = firestore.client()

