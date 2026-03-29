import uuid

from fastapi.testclient import TestClient

from app.main import create_app


def build_client() -> TestClient:
    app = create_app()
    return TestClient(app)


def auth_headers(client: TestClient) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/login",
        json={"account": "13800138000", "password": "123456"},
    )
    payload = response.json()
    token = payload["data"]["token"]
    return {"Authorization": f"Bearer {token}"}


def register_and_login(client: TestClient, account: str) -> dict[str, str]:
    client.post(
        "/api/v1/auth/register",
        json={"account": account, "password": "123456", "nickname": "测试用户"},
    )
    response = client.post(
        "/api/v1/auth/login",
        json={"account": account, "password": "123456"},
    )
    token = response.json()["data"]["token"]
    return {"Authorization": f"Bearer {token}"}


def build_simple_pdf_bytes(text: str) -> bytes:
    escaped = text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
    stream = f"BT\n/F1 12 Tf\n72 72 Td\n({escaped}) Tj\nET".encode("latin-1", errors="ignore")
    objects = [
        b"1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
        b"2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
        (
            b"3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 144] "
            b"/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n"
        ),
        b"4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n",
        b"5 0 obj\n<< /Length "
        + str(len(stream)).encode("ascii")
        + b" >>\nstream\n"
        + stream
        + b"\nendstream\nendobj\n",
    ]
    pdf = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for obj in objects:
        offsets.append(len(pdf))
        pdf.extend(obj)
    xref_offset = len(pdf)
    pdf.extend(f"xref\n0 {len(offsets)}\n".encode("ascii"))
    pdf.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        pdf.extend(f"{offset:010d} 00000 n \n".encode("ascii"))
    pdf.extend(
        (
            f"trailer\n<< /Size {len(offsets)} /Root 1 0 R >>\n"
            f"startxref\n{xref_offset}\n%%EOF"
        ).encode("ascii")
    )
    return bytes(pdf)


def test_products_and_categories() -> None:
    client = build_client()
    categories = client.get("/api/v1/categories")
    assert categories.status_code == 200
    assert categories.json()["data"]

    products = client.get("/api/v1/products")
    assert products.status_code == 200
    assert products.json()["data"]["total"] >= 1


def test_auth_and_favorites_flow() -> None:
    client = build_client()
    headers = auth_headers(client)

    me = client.get("/api/v1/users/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["data"]["account"] == "13800138000"

    favorite = client.post("/api/v1/favorites/102", headers=headers)
    assert favorite.status_code == 200

    favorites = client.get("/api/v1/favorites", headers=headers)
    assert favorites.status_code == 200
    assert favorites.json()["data"]["total"] >= 1


def test_register_change_and_reset_password_flow() -> None:
    client = build_client()
    account = f"tech_user_{uuid.uuid4().hex[:8]}"

    register = client.post(
        "/api/v1/auth/register",
        json={"account": account, "password": "abc123", "nickname": "新用户"},
    )
    assert register.status_code == 200
    token = register.json()["data"]["token"]
    headers = {"Authorization": f"Bearer {token}"}

    change = client.post(
        "/api/v1/auth/change-password",
        headers=headers,
        json={"old_password": "abc123", "new_password": "def456"},
    )
    assert change.status_code == 200

    login_after_change = client.post(
        "/api/v1/auth/login",
        json={"account": account, "password": "def456"},
    )
    assert login_after_change.status_code == 200

    reset = client.post(
        "/api/v1/auth/reset-password",
        json={"account": account, "new_password": "xyz789"},
    )
    assert reset.status_code == 200

    login_after_reset = client.post(
        "/api/v1/auth/login",
        json={"account": account, "password": "xyz789"},
    )
    assert login_after_reset.status_code == 200


def test_register_validation() -> None:
    client = build_client()

    blank_account = client.post(
        "/api/v1/auth/register",
        json={"account": "   ", "password": "123456", "nickname": "新用户"},
    )
    assert blank_account.status_code == 422

    blank_nickname = client.post(
        "/api/v1/auth/register",
        json={"account": "valid_user", "password": "123456", "nickname": "   "},
    )
    assert blank_nickname.status_code == 422

    short_password = client.post(
        "/api/v1/auth/register",
        json={"account": "valid_user", "password": "123", "nickname": "新用户"},
    )
    assert short_password.status_code == 422


def test_search_and_ai_flow() -> None:
    client = build_client()
    headers = auth_headers(client)

    category = client.post(
        "/api/v1/internal/categories",
        json={"name": f"搜索分类-{uuid.uuid4().hex[:6]}", "parent_id": None},
        headers=headers,
    )
    assert category.status_code == 200
    category_id = category.json()["data"]["id"]

    high_price = client.post(
        "/api/v1/internal/products",
        json={
            "category_id": category_id,
            "name": "搜索测试高价件",
            "brand": "SearchBrand",
            "model_no": "SEARCH-H",
            "description": "用于搜索筛选排序分页回归。",
            "price": 199.0,
            "images": [],
            "specs": {"材质": "合金"},
            "compatibility": ["F40"],
            "usage_scenarios": "搜索测试",
            "safety_tips": ["无"],
            "keywords": ["搜索测试件", "高价"],
        },
        headers=headers,
    )
    assert high_price.status_code == 200

    low_price = client.post(
        "/api/v1/internal/products",
        json={
            "category_id": category_id,
            "name": "搜索测试低价件",
            "brand": "SearchBrand",
            "model_no": "SEARCH-L",
            "description": "用于搜索筛选排序分页回归。",
            "price": 29.0,
            "images": [],
            "specs": {"材质": "橡胶"},
            "compatibility": ["F40"],
            "usage_scenarios": "搜索测试",
            "safety_tips": ["无"],
            "keywords": ["搜索测试件", "低价"],
        },
        headers=headers,
    )
    assert low_price.status_code == 200

    search = client.post(
        "/api/v1/search/intelligent-search",
        json={
            "query": "搜索测试件",
            "search_type": "auto",
            "category_id": category_id,
            "sort_by": "price_desc",
            "page": 1,
            "limit": 1,
        },
        headers=headers,
    )
    assert search.status_code == 200
    assert search.json()["data"]["results"]
    assert search.json()["data"]["total"] >= 2
    assert search.json()["data"]["page"] == 1
    assert search.json()["data"]["limit"] == 1
    assert search.json()["data"]["results"][0]["name"] == "搜索测试高价件"

    page_two = client.post(
        "/api/v1/search/intelligent-search",
        json={
            "query": "搜索测试件",
            "search_type": "auto",
            "category_id": category_id,
            "sort_by": "price_desc",
            "page": 2,
            "limit": 1,
        },
        headers=headers,
    )
    assert page_two.status_code == 200
    assert page_two.json()["data"]["results"][0]["name"] == "搜索测试低价件"

    suggestions = client.get("/api/v1/search/suggestions?q=F40")
    assert suggestions.status_code == 200
    assert suggestions.json()["data"]["suggestions"]

    chat = client.post(
        "/api/v1/ai/rag-chat",
        json={"question": "F40 用什么机油滤芯？", "session_id": "session_test"},
        headers=headers,
    )
    assert chat.status_code == 200
    assert chat.json()["data"]["session_id"] == "session_test"
    assert "结论：" in chat.json()["data"]["answer"]

    feedback = client.post(
        "/api/v1/ai/conversations/session_test/feedback",
        json={
            "message_id": chat.json()["data"]["message_id"],
            "rating": 1,
            "comment": "回答清楚",
        },
        headers=headers,
    )
    assert feedback.status_code == 200


def test_knowledge_upload_reindex_and_chat_retrieval() -> None:
    client = build_client()
    headers = auth_headers(client)

    upload = client.post(
        "/api/v1/internal/knowledge/upload-document",
        headers=headers,
        files={
            "file": (
                "bf90-maintenance.txt",
                "BF90 叶轮维护建议\n叶轮出现裂纹、缺角或冷却水流明显减弱时应立即更换。\n建议每季检查一次。",
                "text/plain",
            )
        },
        data={"product_ids": "103"},
    )
    assert upload.status_code == 200
    knowledge_ids = upload.json()["data"]["knowledge_ids"]
    assert knowledge_ids

    reindex = client.post(
        "/api/v1/internal/knowledge/reindex",
        headers=headers,
        json={"knowledge_ids": knowledge_ids, "rebuild_mode": "incremental"},
    )
    assert reindex.status_code == 200
    assert reindex.json()["data"]["status"] == "completed"

    chat = client.post(
        "/api/v1/ai/rag-chat",
        json={"question": "BF90 叶轮什么时候需要更换？", "session_id": "session_bf90"},
        headers=headers,
    )
    assert chat.status_code == 200
    citations = chat.json()["data"]["citations"]
    assert any("bf90-maintenance" in item["title"].lower() for item in citations)

    items = client.get("/api/v1/internal/knowledge/items", headers=headers)
    assert items.status_code == 200
    assert items.json()["data"]["total"] >= 1

    first_item = items.json()["data"]["items"][0]
    update = client.put(
        f"/api/v1/internal/knowledge/items/{first_item['id']}",
        headers=headers,
        json={
            "title": first_item["title"],
            "content": f"{first_item['content']} 补充：建议优先检查冷却水流。",
            "product_ids": [101, 103],
            "engine_models": first_item["engine_models"],
        },
    )
    assert update.status_code == 200
    assert "补充" in update.json()["data"]["content"]
    assert update.json()["data"]["product_ids"] == [101, 103]

    versions = client.get(
        f"/api/v1/internal/knowledge/items/{first_item['id']}/versions",
        headers=headers,
    )
    assert versions.status_code == 200
    assert versions.json()["data"]["total"] >= 2
    assert versions.json()["data"]["versions"][0]["version"] >= 2
    rollback_target = versions.json()["data"]["versions"][-1]["version"]

    rollback = client.post(
        f"/api/v1/internal/knowledge/items/{first_item['id']}/rollback",
        headers=headers,
        json={"version": rollback_target},
    )
    assert rollback.status_code == 200
    assert "补充" not in rollback.json()["data"]["content"]
    assert rollback.json()["data"]["version"] > update.json()["data"]["version"]


def test_pdf_knowledge_upload() -> None:
    client = build_client()
    headers = auth_headers(client)
    pdf_bytes = build_simple_pdf_bytes("BF90 impeller replacement guidance")

    upload = client.post(
        "/api/v1/internal/knowledge/upload-document",
        headers=headers,
        files={
            "file": (
                "bf90-guide.pdf",
                pdf_bytes,
                "application/pdf",
            )
        },
        data={"product_ids": "103"},
    )
    assert upload.status_code == 200
    assert upload.json()["data"]["knowledge_ids"]


def test_batch_delete_knowledge_items() -> None:
    client = build_client()
    headers = auth_headers(client)

    first = client.post(
        "/api/v1/internal/knowledge/upload-document",
        headers=headers,
        files={
            "file": ("batch-a.txt", "F40 批量删除测试 A", "text/plain"),
        },
        data={"product_ids": "101"},
    )
    second = client.post(
        "/api/v1/internal/knowledge/upload-document",
        headers=headers,
        files={
            "file": ("batch-b.txt", "F50 批量删除测试 B", "text/plain"),
        },
        data={"product_ids": "101"},
    )
    ids = [
        first.json()["data"]["knowledge_ids"][0],
        second.json()["data"]["knowledge_ids"][0],
    ]

    deleted = client.post(
        "/api/v1/internal/knowledge/items/batch-delete",
        headers=headers,
        json={"knowledge_ids": ids},
    )
    assert deleted.status_code == 200

    items = client.get("/api/v1/internal/knowledge/items", headers=headers)
    remaining_ids = {item["id"] for item in items.json()["data"]["items"]}
    assert not any(knowledge_id in remaining_ids for knowledge_id in ids)


def test_recognition_feedback_flow() -> None:
    client = build_client()
    headers = auth_headers(client)

    recognize = client.post(
        "/api/v1/ai/recognize-image",
        headers=headers,
        files={"file": ("现场标签.txt", b"Yamaha F40 oil filter 69J-13440-03", "text/plain")},
        data={"source": "camera"},
    )
    assert recognize.status_code == 200
    recognition_id = recognize.json()["data"]["recognition_id"]

    feedback = client.post(
        f"/api/v1/ai/recognitions/{recognition_id}/feedback",
        headers=headers,
        json={
            "feedback_type": "wrong_product",
            "correct_product_id": 101,
            "comment": "应归到雅马哈F40机油滤芯",
        },
    )
    assert feedback.status_code == 200
    assert feedback.json()["data"]["message"] == "反馈已记录"


def test_internal_create_category_and_product() -> None:
    client = build_client()
    headers = auth_headers(client)

    category = client.post(
        "/api/v1/internal/categories",
        json={"name": "密封件", "parent_id": None},
        headers=headers,
    )
    assert category.status_code == 200
    category_id = category.json()["data"]["id"]

    product = client.post(
        "/api/v1/internal/products",
        json={
            "category_id": category_id,
            "name": "耐油 O 型圈",
            "brand": "SealPro",
            "model_no": "SP-OR-01",
            "description": "适用于常见船外机密封维护。",
            "price": 9.9,
            "images": ["https://oss.example.com/products/o-ring.jpg"],
            "specs": {"材质": "丁腈橡胶"},
            "compatibility": ["通用"],
            "usage_scenarios": "密封维护",
            "safety_tips": ["避免高温暴晒"],
            "keywords": ["O 型圈", "密封件"],
        },
        headers=headers,
    )
    assert product.status_code == 200
    assert product.json()["data"]["category_id"] == category_id


def test_update_profile_and_conversation_detail() -> None:
    client = build_client()
    headers = auth_headers(client)

    profile = client.put(
        "/api/v1/users/me",
        headers=headers,
        json={
            "nickname": "现场管理员",
            "avatar_url": "https://oss.example.com/avatar-updated.jpg",
        },
    )
    assert profile.status_code == 200
    assert profile.json()["data"]["nickname"] == "现场管理员"
    assert profile.json()["data"]["avatar_url"] == "https://oss.example.com/avatar-updated.jpg"

    avatar = client.post(
        "/api/v1/users/me/avatar",
        headers=headers,
        files={"file": ("avatar.jpg", b"fake-image-bytes", "image/jpeg")},
    )
    assert avatar.status_code == 200
    assert "/local-uploads/" in avatar.json()["data"]["avatar_url"]

    session_id = "session_detail_test"
    chat = client.post(
        "/api/v1/ai/rag-chat",
        json={"question": "F40 用什么机油滤芯？", "session_id": session_id},
        headers=headers,
    )
    assert chat.status_code == 200

    detail = client.get(f"/api/v1/ai/conversations/{session_id}", headers=headers)
    assert detail.status_code == 200
    messages = detail.json()["data"]["messages"]
    assert len(messages) >= 2
    assert messages[0]["role"] == "user"
    assert messages[1]["role"] == "assistant"


def test_internal_update_and_delete_product() -> None:
    client = build_client()
    headers = auth_headers(client)

    created = client.post(
        "/api/v1/internal/products",
        json={
            "category_id": 1,
            "name": "测试维护滤芯",
            "brand": "TestBrand",
            "model_no": "TB-01",
            "description": "用于商品编辑删除回归。",
            "price": 19.9,
            "images": ["https://oss.example.com/products/test-filter.jpg"],
            "specs": {"材质": "复合材料"},
            "compatibility": ["F40"],
            "usage_scenarios": "保养维护",
            "safety_tips": ["安装前核对接口"],
            "keywords": ["测试滤芯"],
        },
        headers=headers,
    )
    assert created.status_code == 200
    product_id = created.json()["data"]["id"]

    updated = client.put(
        f"/api/v1/internal/products/{product_id}",
        json={
            "category_id": 1,
            "name": "测试维护滤芯-已更新",
            "brand": "TestBrand",
            "model_no": "TB-02",
            "description": "更新后的商品描述。",
            "price": 29.9,
            "images": ["https://oss.example.com/products/test-filter-2.jpg"],
            "specs": {"材质": "升级材料"},
            "compatibility": ["F40", "F50"],
            "usage_scenarios": "保养维护、库存回填",
            "safety_tips": ["安装前核对接口", "确认密封圈状态"],
            "keywords": ["测试滤芯", "更新"],
        },
        headers=headers,
    )
    assert updated.status_code == 200

    detail = client.get(f"/api/v1/products/{product_id}")
    assert detail.status_code == 200
    assert detail.json()["data"]["name"] == "测试维护滤芯-已更新"
    assert detail.json()["data"]["model"] == "TB-02"

    deleted = client.delete(f"/api/v1/internal/products/{product_id}", headers=headers)
    assert deleted.status_code == 200

    deleted_detail = client.get(f"/api/v1/products/{product_id}")
    assert deleted_detail.status_code == 404


def test_internal_endpoints_require_admin() -> None:
    client = build_client()
    headers = register_and_login(client, "ops_user")

    response = client.get("/api/v1/internal/knowledge/items", headers=headers)
    assert response.status_code == 403
