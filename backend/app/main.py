from datetime import datetime, timezone, timedelta
import hashlib
import hmac
import secrets
import sqlite3
from pathlib import Path
from fastapi import Depends, Header
from enum import Enum
from typing import Optional
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(
    title="EcoLoop UG API",
    description="Academic MVP API scaffold for waste listings and collection requests.",
    version="0.1.0",
)

# Development-only CORS configuration. Restrict origins before production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ListingStatus(str, Enum):
    available = "available"
    requested = "requested"
    collected = "collected"
    cancelled = "cancelled"


class WasteCategory(BaseModel):
    id: str
    name: str
    description: str


class WasteListingCreate(BaseModel):
    household_id: str = Field(min_length=1, max_length=80)
    category_id: str = Field(min_length=1, max_length=80)
    quantity_kg: float = Field(gt=0, le=100000)
    description: str = Field(default="", max_length=1000)
    location_label: str = Field(min_length=1, max_length=200)
    latitude: Optional[float] = Field(default=None, ge=-90, le=90)
    longitude: Optional[float] = Field(default=None, ge=-180, le=180)


class WasteListing(WasteListingCreate):
    id: str
    status: ListingStatus
    created_at: datetime


class CollectionRequestCreate(BaseModel):
    listing_id: str
    collector_id: str = Field(min_length=1, max_length=80)


class CollectionRequest(BaseModel):
    id: str
    listing_id: str
    collector_id: str
    status: str
    created_at: datetime
    updated_at: datetime


categories = [
    WasteCategory(id="plastic", name="Plastic", description="Plastic bottles and accepted packaging."),
    WasteCategory(id="paper", name="Paper & cardboard", description="Clean paper and cardboard."),
    WasteCategory(id="metal", name="Metal", description="Accepted scrap metal and cans."),
    WasteCategory(id="organic", name="Organic", description="Food and garden waste."),
    WasteCategory(id="glass", name="Glass", description="Glass bottles and containers."),
]
listings: dict[str, WasteListing] = {}
collections: dict[str, CollectionRequest] = {}


@app.get("/")
def root():
    return {"name": "EcoLoop UG API", "version": "0.1.0", "stage": "academic MVP scaffold"}


@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.now(timezone.utc)}


@app.get("/api/v1/categories", response_model=list[WasteCategory])
def get_categories():
    return categories


@app.get("/api/v1/listings", response_model=list[WasteListing])
def get_listings():
    return sorted(listings.values(), key=lambda item: item.created_at, reverse=True)


@app.post("/api/v1/listings", response_model=WasteListing, status_code=201)
def create_listing(payload: WasteListingCreate):
    if payload.category_id not in {item.id for item in categories}:
        raise HTTPException(status_code=400, detail="Unknown waste category.")
    listing = WasteListing(
        id=str(uuid4()),
        **payload.model_dump(),
        status=ListingStatus.available,
        created_at=datetime.now(timezone.utc),
    )
    listings[listing.id] = listing
    return listing


@app.post("/api/v1/collections", response_model=CollectionRequest, status_code=201)
def create_collection(payload: CollectionRequestCreate):
    listing = listings.get(payload.listing_id)
    if listing is None:
        raise HTTPException(status_code=404, detail="Waste listing not found.")
    if listing.status != ListingStatus.available:
        raise HTTPException(status_code=409, detail="Listing is not available.")
    now = datetime.now(timezone.utc)
    request = CollectionRequest(
        id=str(uuid4()),
        listing_id=payload.listing_id,
        collector_id=payload.collector_id,
        status="assigned",
        created_at=now,
        updated_at=now,
    )
    listings[payload.listing_id] = listing.model_copy(update={"status": ListingStatus.requested})
    collections[request.id] = request
    return request


@app.patch("/api/v1/collections/{collection_id}/status", response_model=CollectionRequest)
def update_collection_status(collection_id: str, status: str):
    allowed = {"assigned", "scheduled", "collected", "completed", "cancelled"}
    if status not in allowed:
        raise HTTPException(status_code=400, detail=f"Status must be one of: {', '.join(sorted(allowed))}")
    request = collections.get(collection_id)
    if request is None:
        raise HTTPException(status_code=404, detail="Collection request not found.")
    updated = request.model_copy(update={"status": status, "updated_at": datetime.now(timezone.utc)})
    collections[collection_id] = updated
    if status == "cancelled" and collection_id in collections:
        listing = listings[request.listing_id]
        listings[request.listing_id] = listing.model_copy(update={"status": ListingStatus.available})
    elif status in {"collected", "completed"}:
        listing = listings[request.listing_id]
        listings[request.listing_id] = listing.model_copy(update={"status": ListingStatus.collected})
    return updated


# --- Persistent account and public community directory ---
DB_PATH = Path(__file__).resolve().parent.parent / "ecoloop.db"
VALID_ROLES = {"household", "collector", "recycler", "organization"}
TOKEN_TTL_HOURS = 24 * 7

def db_connection():
    conn = sqlite3.connect(DB_PATH, timeout=10)
    conn.row_factory = sqlite3.Row
    return conn

def init_auth_db():
    with db_connection() as conn:
        conn.execute("""CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY, full_name TEXT NOT NULL, username TEXT NOT NULL COLLATE NOCASE UNIQUE,
            email TEXT NOT NULL COLLATE NOCASE UNIQUE, password_salt TEXT NOT NULL,
            password_hash TEXT NOT NULL, role TEXT NOT NULL, location_label TEXT NOT NULL,
            created_at TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 1
        )""")
        conn.execute("""CREATE TABLE IF NOT EXISTS auth_tokens (
            token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL,
            expires_at TEXT NOT NULL, created_at TEXT NOT NULL,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        )""")

init_auth_db()

class RegisterPayload(BaseModel):
    full_name: str = Field(min_length=2, max_length=100)
    username: str = Field(min_length=3, max_length=24, pattern=r"^[A-Za-z0-9_.]+$")
    email: str = Field(min_length=5, max_length=254)
    password: str = Field(min_length=8, max_length=128)
    role: str
    location_label: str = Field(min_length=2, max_length=120)

class LoginPayload(BaseModel):
    email: str = Field(min_length=5, max_length=254)
    password: str = Field(min_length=1, max_length=128)

def _public_user(row):
    return {"id": row["id"], "full_name": row["full_name"], "username": row["username"],
            "email": row["email"], "role": row["role"], "location_label": row["location_label"],
            "created_at": row["created_at"]}

def _hash_password(password: str, salt: bytes | None = None):
    salt = salt or secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 240_000)
    return salt.hex(), digest.hex()

def _issue_token(user_id: str):
    token = secrets.token_urlsafe(40)
    now = datetime.now(timezone.utc)
    with db_connection() as conn:
        conn.execute("INSERT INTO auth_tokens(token_hash,user_id,expires_at,created_at) VALUES(?,?,?,?)",
            (hashlib.sha256(token.encode()).hexdigest(), user_id,
             (now + timedelta(hours=TOKEN_TTL_HOURS)).isoformat(), now.isoformat()))
    return token

def _get_current_user(authorization: str | None = Header(default=None)):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Please sign in to continue.")
    token = authorization.split(" ", 1)[1].strip()
    digest = hashlib.sha256(token.encode()).hexdigest()
    with db_connection() as conn:
        row = conn.execute("""SELECT u.* FROM auth_tokens t JOIN users u ON u.id=t.user_id
            WHERE t.token_hash=? AND t.expires_at>? AND u.is_active=1""",
            (digest, datetime.now(timezone.utc).isoformat())).fetchone()
    if row is None:
        raise HTTPException(status_code=401, detail="Your session expired. Please sign in again.")
    return _public_user(row)

@app.post("/api/v1/auth/register", status_code=201)
def register(payload: RegisterPayload):
    email = payload.email.strip().lower()
    username = payload.username.strip()
    if "@" not in email or "." not in email.rsplit("@", 1)[-1]:
        raise HTTPException(status_code=422, detail="Enter a valid email address.")
    if payload.role not in VALID_ROLES:
        raise HTTPException(status_code=422, detail="Choose a valid account type.")
    salt, password_hash = _hash_password(payload.password)
    user_id = str(uuid4())
    now = datetime.now(timezone.utc).isoformat()
    try:
        with db_connection() as conn:
            conn.execute("""INSERT INTO users(id,full_name,username,email,password_salt,password_hash,role,location_label,created_at)
                VALUES(?,?,?,?,?,?,?,?,?)""", (user_id, payload.full_name.strip(), username, email, salt, password_hash,
                payload.role, payload.location_label.strip(), now))
            row = conn.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
    except sqlite3.IntegrityError as exc:
        message = str(exc).lower()
        if "username" in message:
            raise HTTPException(status_code=409, detail="That username is already taken. Choose another.")
        raise HTTPException(status_code=409, detail="An account with that email already exists. Sign in instead.")
    token = _issue_token(user_id)
    return {"token": token, "token_type": "bearer", "expires_in_hours": TOKEN_TTL_HOURS, "user": _public_user(row)}

@app.post("/api/v1/auth/login")
def login(payload: LoginPayload):
    email = payload.email.strip().lower()
    with db_connection() as conn:
        row = conn.execute("SELECT * FROM users WHERE email=? AND is_active=1", (email,)).fetchone()
    if row is None:
        raise HTTPException(status_code=401, detail="No account matches those details. Please create an account.")
    salt = bytes.fromhex(row["password_salt"])
    attempted = hashlib.pbkdf2_hmac("sha256", payload.password.encode("utf-8"), salt, 240_000).hex()
    if not hmac.compare_digest(attempted, row["password_hash"]):
        raise HTTPException(status_code=401, detail="Email or password is incorrect. Try again or create an account.")
    token = _issue_token(row["id"])
    return {"token": token, "token_type": "bearer", "expires_in_hours": TOKEN_TTL_HOURS, "user": _public_user(row)}

@app.get("/api/v1/auth/me")
def current_user(user=Depends(_get_current_user)):
    return user

@app.post("/api/v1/auth/logout", status_code=204)
def logout(authorization: str | None = Header(default=None)):
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    token = authorization.split(" ", 1)[1].strip()
    with db_connection() as conn:
        conn.execute("DELETE FROM auth_tokens WHERE token_hash=?", (hashlib.sha256(token.encode()).hexdigest(),))
    return None

@app.get("/api/v1/users")
def list_public_users(role: str | None = None, q: str | None = None, limit: int = 50, offset: int = 0):
    """Public community directory; never returns email, password hashes, or tokens."""
    limit = max(1, min(limit, 100))
    query = "SELECT id,full_name,username,email,role,location_label,created_at FROM users WHERE is_active=1"
    params = []
    if role:
        if role not in VALID_ROLES:
            raise HTTPException(status_code=400, detail="Unknown user role.")
        query += " AND role=?"; params.append(role)
    if q:
        query += " AND (full_name LIKE ? OR username LIKE ? OR location_label LIKE ?)"
        term = f"%{q.strip()}%"; params.extend([term, term, term])
    query += " ORDER BY created_at DESC LIMIT ? OFFSET ?"; params.extend([limit, max(0, offset)])
    with db_connection() as conn:
        rows = conn.execute(query, params).fetchall()
        total = conn.execute("SELECT COUNT(*) FROM users WHERE is_active=1").fetchone()[0]
    return {"items": [{"id": r["id"], "full_name": r["full_name"], "username": r["username"],
        "role": r["role"], "location_label": r["location_label"], "created_at": r["created_at"]} for r in rows], "total": total, "limit": limit, "offset": max(0, offset)}
