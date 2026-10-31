from fastapi.testclient import TestClient

from app.main import app

# No `with` block: skips lifespan, so no Redis/worker is needed.
client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_protected_routes_reject_anonymous():
    for path in ("/api/v1/profile", "/api/v1/clothing", "/api/v1/analytics/wardrobe"):
        assert client.get(path).status_code in (401, 403), path


def test_oversized_body_rejected():
    r = client.post("/health", headers={"content-length": str(21 * 1024 * 1024)})
    assert r.status_code == 413
