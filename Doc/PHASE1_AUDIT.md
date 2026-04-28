# Dressify — Phase 1 Audit (Open Items)

> Last updated: 2026-04-26. Everything listed here is **not yet fixed** or implemented.

---

## 1. Backend

### 1.1 Test suite has no real assertions
**Directory:** [Backend/tests/](Backend/tests/)

The test files (`test_auth.py`, `test_upload.py`, `test_outfits.py`) exist but contain no real assertions or fixtures yet. Needs: pytest fixtures for DB + auth, at minimum one smoke test per endpoint, and CI integration.

---

## 2. Priority Order

| Priority | Item |
|---|---|
| 🟠 P1 | Fill out backend test assertions + CI |
