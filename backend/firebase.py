# backend/firebase.py

import firebase_admin
from firebase_admin import credentials, firestore

# Path to your Firebase service account JSON
cred = credentials.Certificate("C:\\Users\\ghjgjhgjgjg\\Desktop\\swipify\\backend\\serviceAccountKey.json")
# Initialize Firebase app (only once)
firebase_admin.initialize_app(cred)

# Create Firestore client
db = firestore.client()

users_ref = db.collection("users")
docs = users_ref.stream()
for doc in docs:
    print(doc.id, doc.to_dict())