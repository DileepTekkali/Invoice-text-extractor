from pymongo import MongoClient
from bson import ObjectId
import os
from dotenv import load_dotenv

load_dotenv()

MONGODB_URI = os.getenv("MongoDbURL", os.getenv("MONGODB_URI", ""))
DATABASE_NAME = os.getenv("DATABASE_NAME", "invoicetextextractor")

_client = None
_db = None

def get_database():
    global _client, _db
    if _client is None:
        if not MONGODB_URI:
            raise ValueError("MongoDB URI not configured. Please set MongoDbURL in .env file.")
        _client = MongoClient(MONGODB_URI)
        _db = _client[DATABASE_NAME]
    return _db

def get_invoices_collection():
    db = get_database()
    return db["invoices"]

def close_database():
    global _client, _db
    if _client:
        _client.close()
        _client = None
        _db = None
