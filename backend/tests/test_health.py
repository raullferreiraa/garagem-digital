from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_health() -> None:
    response = client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_auth_me_exige_bearer_token() -> None:
    response = client.get("/api/v1/auth/me")

    assert response.status_code == 401
    assert response.json() == {"detail": "Autenticacao necessaria."}
