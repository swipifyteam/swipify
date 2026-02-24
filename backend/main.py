# main.py
from fastapi import FastAPI
from pydantic import BaseModel
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase Admin
cred = credentials.Certificate("serviceAccountKey.json")  # Path to your JSON key
firebase_admin.initialize_app(cred)

db = firestore.client()

app = FastAPI()

# Pydantic model for a User
class User(BaseModel):
    name: str
    age: int

# Add a user to Firestore
@app.post("/users/add")
async def add_user(user: User):
    doc_ref = db.collection("users").add(user.dict())
    return {"status": "success", "id": str(doc_ref[1].id)}

# Get all users from Firestore
@app.get("/users/all")
async def get_users():
    users_ref = db.collection("users").stream()
    users = [doc.to_dict() for doc in users_ref]
    return users

# Optional root
@app.get("/")
async def root():
    return {"message": "FastAPI + Firebase is working!"}