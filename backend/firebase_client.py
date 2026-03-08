# firebase_client.py
# Shared Firebase Admin SDK initialization and Firestore client.
# Import `db` from this module in all routers and services.

import firebase_admin
from firebase_admin import credentials, firestore
import os

# Initialize Firebase Admin SDK only once
if not firebase_admin._apps:
    cred = credentials.Certificate(
        os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")
    )
    firebase_admin.initialize_app(cred)

# Shared Firestore client — use this in all routers
db = firestore.client()
