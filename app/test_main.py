from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_liveness_probe():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "alive"}

def test_metrics_endpoint():
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "http_requests_total" in response.text
