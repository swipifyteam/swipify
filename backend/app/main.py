# app/main.py
from fastapi import FastAPI

app = FastAPI(title="Swipify Backend")

@app.get("/")
def home():
    return {"message": "Swipify Backend Running!"}