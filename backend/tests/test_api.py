from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_categories():
    response = client.get("/api/v1/categories")
    assert response.status_code == 200
    assert len(response.json()) >= 1
