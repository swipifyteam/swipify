from fastapi import FastAPI, Depends, HTTPException, Request
from firebase_admin import credentials, auth, firestore, initialize_app
import firebase_admin
from fastapi.middleware.cors import CORSMiddleware

# Initialize Firebase Admin
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

app = FastAPI()

origins = [
    "http://localhost:55453",  # Flutter Web dev server
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 🔐 Verify Firebase ID Token
async def verify_token(request: Request):
    id_token = request.headers.get("Authorization")

    if not id_token:
        raise HTTPException(status_code=401, detail="Missing token")

    try:
        decoded_token = auth.verify_id_token(id_token)
        return decoded_token
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")


# ✅ Create user document in Firestore
@app.post("/create-user")
async def create_user(data: dict, user=Depends(verify_token)):

    uid = user["uid"]

    user_ref = db.collection("users").document(uid)

    user_ref.set({
        "uid": uid,
        "email": user["email"],
        "fullName": data.get("fullName"),
        "createdAt": firestore.SERVER_TIMESTAMP
    })

    return {"message": "User created successfully"}