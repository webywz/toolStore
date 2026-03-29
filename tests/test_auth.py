import uuid


def test_register(client):
    account = f"auth_user_{uuid.uuid4().hex[:8]}"
    response = client.post("/api/v1/auth/register", json={
        "account": account,
        "password": "test123",
        "nickname": "测试用户",
    })
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "token" in data["data"]


def test_login(client):
    account = f"auth_user_{uuid.uuid4().hex[:8]}"
    client.post("/api/v1/auth/register", json={
        "account": account,
        "password": "test123",
        "nickname": "测试",
    })
    response = client.post("/api/v1/auth/login", json={
        "account": account,
        "password": "test123",
    })
    assert response.status_code == 200
    assert response.json()["success"] is True
