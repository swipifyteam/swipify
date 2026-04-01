
import firebase_admin
from firebase_admin import credentials, storage
import os

cred = credentials.Certificate(os.path.join(os.path.dirname(__file__), "serviceAccountKey.json"))
if not firebase_admin._apps:
    app = firebase_admin.initialize_app(cred)
else:
    app = firebase_admin.get_app()

bucket = storage.bucket()
print(f"Bucket name: {bucket.name}")
