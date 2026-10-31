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


def test_outfit_prompt_formats():
    # Regression: unescaped braces in the example JSON made every generation fail.
    from app.services.ai_outfit_generator import _PROMPT_TEMPLATE

    out = _PROMPT_TEMPLATE.format(
        occasion="work", weather="sunny", seed_line="", style_line="", recent_line="", wardrobe="w"
    )
    assert '{"item_ids"' in out


def _jpeg(w, h):
    import io
    from PIL import Image

    buf = io.BytesIO()
    Image.new("RGB", (w, h), (120, 80, 60)).save(buf, format="JPEG")
    return buf.getvalue()


def test_prepare_photo_normalises_to_768x1024():
    import io
    from PIL import Image
    from app.routers.tryon import _prepare_photo

    out = Image.open(io.BytesIO(_prepare_photo(_jpeg(900, 1400))))
    assert out.size == (768, 1024)


def test_prepare_photo_rejects_bad_input():
    import pytest
    from fastapi import HTTPException
    from app.routers.tryon import _prepare_photo

    for bad in (b"", b"not an image", _jpeg(200, 300), _jpeg(1600, 900)):
        with pytest.raises(HTTPException) as e:
            _prepare_photo(bad)
        assert e.value.status_code in (400, 422)


def test_tryon_photo_requires_auth():
    assert client.get("/api/v1/tryon/photo").status_code in (401, 403)
    assert client.delete("/api/v1/tryon/photo").status_code in (401, 403)
