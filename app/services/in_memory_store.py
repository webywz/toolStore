from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import secrets
import uuid

from app.core.exceptions import BusinessError


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


@dataclass
class UserRecord:
    id: int
    phone: str
    password: str
    nickname: str
    avatar_url: str | None
    created_at: datetime


class InMemoryStore:
    def __init__(self) -> None:
        self.users: dict[int, UserRecord] = {}
        self.users_by_phone: dict[str, int] = {}
        self.tokens: dict[str, int] = {}
        self.search_histories: dict[int, list[dict]] = {}
        self.favorite_product_ids: dict[int, set[int]] = {}
        self.recognitions: dict[str, dict] = {}
        self.recognition_feedback: list[dict] = []
        self.conversations: dict[str, dict] = {}
        self.conversation_feedback: list[dict] = []
        self.knowledge_jobs: dict[int, dict] = {}
        self.next_user_id = 1
        self.next_knowledge_id = 1001
        self.next_job_id = 1

        self.categories = self._seed_categories()
        self.products = self._seed_products()
        self.knowledge = self._seed_knowledge()
        self._seed_user()

    def _seed_categories(self) -> list[dict]:
        return [
            {
                "id": 1,
                "name": "挂机配件",
                "icon_url": "https://oss.example.com/icons/outboard.png",
                "children": [
                    {"id": 11, "name": "滤芯", "icon_url": None},
                    {"id": 12, "name": "火花塞", "icon_url": None},
                ],
            },
            {
                "id": 2,
                "name": "冷却系统",
                "icon_url": "https://oss.example.com/icons/cooling.png",
                "children": [
                    {"id": 21, "name": "叶轮", "icon_url": None},
                    {"id": 22, "name": "泵体", "icon_url": None},
                ],
            },
            {
                "id": 3,
                "name": "通用紧固件",
                "icon_url": "https://oss.example.com/icons/fastener.png",
                "children": [
                    {"id": 31, "name": "螺丝", "icon_url": None},
                    {"id": 32, "name": "卡箍", "icon_url": None},
                ],
            },
        ]

    def _seed_products(self) -> list[dict]:
        return [
            {
                "id": 101,
                "category_id": 1,
                "category": "挂机配件",
                "name": "雅马哈F40机油滤芯",
                "brand": "Yamaha",
                "model_no": "69J-13440-03",
                "description": "适用于雅马哈 F40/F50/F60 挂机的常规保养机油滤芯。",
                "price": 89.0,
                "images": [
                    "https://oss.example.com/products/101-1.jpg",
                    "https://oss.example.com/products/101-2.jpg",
                ],
                "specs": {
                    "型号": "69J-13440-03",
                    "更换周期": "100小时",
                    "材质": "复合滤纸",
                },
                "compatibility": ["F40", "F50", "F60"],
                "usage_scenarios": "挂机保养、定期更换",
                "safety_tips": ["检查 O 型圈", "按保养周期更换"],
                "keywords": ["雅马哈", "F40", "机油滤芯"],
                "created_at": utcnow(),
            },
            {
                "id": 102,
                "category_id": 1,
                "category": "挂机配件",
                "name": "铃木DF60火花塞",
                "brand": "Suzuki",
                "model_no": "NGK DPR6EA-9",
                "description": "适用于铃木 DF60/DF70 挂机，适合启动性能恢复。",
                "price": 42.0,
                "images": ["https://oss.example.com/products/102.jpg"],
                "specs": {
                    "型号": "NGK DPR6EA-9",
                    "间隙": "0.9 mm",
                    "扭矩建议": "18 N·m",
                },
                "compatibility": ["DF60", "DF70"],
                "usage_scenarios": "点火维护、冷启动排查",
                "safety_tips": ["避免热机状态拆装", "安装前清洁螺纹孔"],
                "keywords": ["铃木", "DF60", "火花塞"],
                "created_at": utcnow(),
            },
            {
                "id": 103,
                "category_id": 2,
                "category": "冷却系统",
                "name": "本田BF90水泵叶轮",
                "brand": "Honda",
                "model_no": "19210-ZW1-B04",
                "description": "适用于 BF75/BF90 冷却系统维护，更换周期明确。",
                "price": 168.0,
                "images": ["https://oss.example.com/products/103.jpg"],
                "specs": {
                    "型号": "19210-ZW1-B04",
                    "材质": "耐海水橡胶",
                    "建议周期": "每季检查",
                },
                "compatibility": ["BF75", "BF90"],
                "usage_scenarios": "冷却流量不足、年度保养",
                "safety_tips": ["检查泵壳磨损", "安装时涂少量润滑剂"],
                "keywords": ["本田", "BF90", "叶轮"],
                "created_at": utcnow(),
            },
            {
                "id": 104,
                "category_id": 3,
                "category": "通用紧固件",
                "name": "316不锈钢螺丝 M6×20",
                "brand": "MarineFix",
                "model_no": "MF-M6-20",
                "description": "船用耐腐蚀 316 不锈钢螺丝，适用于常见固定场景。",
                "price": 12.0,
                "images": ["https://oss.example.com/products/104.jpg"],
                "specs": {
                    "规格": "M6×20",
                    "材质": "316 不锈钢",
                    "包装": "10只/包",
                },
                "compatibility": ["通用"],
                "usage_scenarios": "船体固定、挂机安装",
                "safety_tips": ["避免过度拧紧", "定期检查腐蚀情况"],
                "keywords": ["316", "不锈钢螺丝", "M6"],
                "created_at": utcnow(),
            },
        ]

    def _seed_knowledge(self) -> list[dict]:
        return [
            {
                "id": 1001,
                "title": "雅马哈F40机油滤芯适配",
                "snippet": "适用机型：F40、F50A、F60；推荐型号 69J-13440-03。",
                "product_ids": [101],
            },
            {
                "id": 1002,
                "title": "DF60 点火维护建议",
                "snippet": "建议火花塞间隙 0.9 mm，电极烧蚀明显时直接更换。",
                "product_ids": [102],
            },
            {
                "id": 1003,
                "title": "叶轮老化检查",
                "snippet": "叶轮出现裂纹、变形或冷却流量下降时应优先更换。",
                "product_ids": [103],
            },
        ]

    def _seed_user(self) -> None:
        user = UserRecord(
            id=self.next_user_id,
            phone="13800138000",
            password="123456",
            nickname="张三",
            avatar_url="https://oss.example.com/avatar.jpg",
            created_at=utcnow(),
        )
        self.users[user.id] = user
        self.users_by_phone[user.phone] = user.id
        self.next_user_id += 1
        token = self._issue_token(user.id)
        self.favorite_product_ids[user.id] = {101}
        self.search_histories[user.id] = [
            {
                "query_text": "F40 机油滤芯",
                "search_type": "model",
                "created_at": utcnow(),
            },
            {
                "query_text": "O 型圈",
                "search_type": "keyword",
                "created_at": utcnow(),
            },
        ]
        self.chat(
            user_id=user.id,
            question="F40 用什么机油滤芯？",
            session_id="session_123",
        )
        self.create_recognition(user.id, filename="sample-f40.jpg", source="camera")
        self.default_token = token

    def _issue_token(self, user_id: int) -> str:
        token = secrets.token_urlsafe(24)
        self.tokens[token] = user_id
        return token

    def get_user_by_token(self, token: str) -> UserRecord | None:
        user_id = self.tokens.get(token)
        if user_id is None:
            return None
        return self.users.get(user_id)

    def register_user(self, account: str, password: str, nickname: str) -> dict:
        if account in self.users_by_phone:
            raise BusinessError(status_code=409, code=10003, message="账号已注册")
        user = UserRecord(
            id=self.next_user_id,
            phone=account,
            password=password,
            nickname=nickname,
            avatar_url=None,
            created_at=utcnow(),
        )
        self.users[user.id] = user
        self.users_by_phone[account] = user.id
        self.favorite_product_ids[user.id] = set()
        self.search_histories[user.id] = []
        self.next_user_id += 1
        token = self._issue_token(user.id)
        return {"user_id": user.id, "token": token, "nickname": user.nickname}

    def login_user(self, account: str, password: str) -> dict:
        user_id = self.users_by_phone.get(account)
        if user_id is None:
            raise BusinessError(status_code=404, code=10001, message="用户不存在")
        user = self.users[user_id]
        if user.password != password:
            raise BusinessError(status_code=401, code=10002, message="密码错误")
        token = self._issue_token(user.id)
        return {"user_id": user.id, "token": token, "nickname": user.nickname}

    def list_products(self, *, page: int, limit: int, category_id: int | None, keyword: str | None) -> dict:
        items = self.products
        if category_id is not None:
            items = [item for item in items if item["category_id"] == category_id]
        if keyword:
            lowered = keyword.lower()
            items = [
                item
                for item in items
                if lowered in " ".join(
                    [
                        item["name"],
                        item["brand"],
                        item["model_no"],
                        item["category"],
                        *item["keywords"],
                        *item["compatibility"],
                    ]
                ).lower()
            ]
        total = len(items)
        start = (page - 1) * limit
        end = start + limit
        page_items = items[start:end]
        return {
            "total": total,
            "page": page,
            "limit": limit,
            "products": [
                {
                    "id": item["id"],
                    "name": item["name"],
                    "price": item["price"],
                    "images": item["images"],
                    "category": item["category"],
                    "compatibility": item["compatibility"],
                }
                for item in page_items
            ],
        }

    def get_product(self, product_id: int) -> dict:
        for item in self.products:
            if item["id"] == product_id:
                return item
        raise BusinessError(status_code=404, code=20001, message="商品不存在")

    def list_categories(self) -> list[dict]:
        return self.categories

    def intelligent_search(
        self,
        *,
        query: str,
        search_type: str,
        category_id: int | None = None,
        min_price: float | None = None,
        max_price: float | None = None,
        sort_by: str = "relevance",
        page: int = 1,
        limit: int = 10,
        user_id: int | None,
    ) -> dict:
        effective_type = self._detect_search_type(query) if search_type == "auto" else search_type
        lowered = query.lower()
        matches = []
        for product in self.products:
            if category_id is not None and product["category_id"] != category_id:
                continue
            if min_price is not None and product["price"] < min_price:
                continue
            if max_price is not None and product["price"] > max_price:
                continue
            haystack = " ".join(
                [
                    product["name"],
                    product["brand"],
                    product["model_no"],
                    product["category"],
                    *product["keywords"],
                    *product["compatibility"],
                ]
            ).lower()
            if lowered not in haystack and effective_type != "semantic":
                continue
            score = 0.97 if lowered in product["model_no"].lower() else 0.88
            if effective_type == "semantic":
                score = 0.84
            matches.append(
                (score, product)
            )
        if not matches:
            fallback = self.products
            if category_id is not None:
                fallback = [product for product in fallback if product["category_id"] == category_id]
            if min_price is not None:
                fallback = [product for product in fallback if product["price"] >= min_price]
            if max_price is not None:
                fallback = [product for product in fallback if product["price"] <= max_price]
            matches = [(0.62, product) for product in fallback[:2]]
            effective_type = "semantic"
        if sort_by == "price_asc":
            matches.sort(key=lambda item: (item[1]["price"], -item[0], item[1]["id"]))
        elif sort_by == "price_desc":
            matches.sort(key=lambda item: (item[1]["price"], item[0], item[1]["id"]), reverse=True)
        elif sort_by == "newest":
            matches.sort(key=lambda item: (item[1]["created_at"], item[0], item[1]["id"]), reverse=True)
        else:
            matches.sort(key=lambda item: (item[0], item[1]["id"]), reverse=True)
        total = len(matches)
        paged = matches[(page - 1) * limit : page * limit]
        results = [
            {
                "product_id": product["id"],
                "name": product["name"],
                "price": product["price"],
                "image": product["images"][0],
                "score": score,
                "match_reason": self._match_reason(effective_type)
                if score != 0.62
                else "语义近似召回",
            }
            for score, product in paged
        ]
        if user_id is not None:
            self.search_histories.setdefault(user_id, []).insert(
                0,
                {
                    "query_text": query,
                    "search_type": effective_type,
                    "created_at": utcnow(),
                },
            )
        return {
            "query": query,
            "search_type": effective_type,
            "total": total,
            "page": page,
            "limit": limit,
            "results": results,
        }

    def search_suggestions(self, q: str) -> list[str]:
        lowered = q.lower()
        candidates: list[str] = []
        for product in self.products:
            variants = [product["name"], f'{product["model_no"]} {product["name"]}']
            candidates.extend(variants)
        unique = []
        seen = set()
        for item in candidates:
            if lowered in item.lower() and item not in seen:
                seen.add(item)
                unique.append(item)
        return unique[:8]

    def get_search_histories(self, user_id: int) -> list[dict]:
        return self.search_histories.get(user_id, [])

    def create_recognition(self, user_id: int, *, filename: str, source: str) -> dict:
        product = self.products[0] if "f40" in filename.lower() else self.products[-1]
        recognition_id = f"rec_{uuid.uuid4().hex[:8]}"
        record = {
            "recognition_id": recognition_id,
            "user_id": user_id,
            "image_url": f"https://oss.example.com/uploads/{filename}",
            "confidence": 0.86 if product["id"] == 101 else 0.81,
            "result": {
                "item_name": product["name"],
                "category": product["category"],
                "description": product["description"],
                "features": list(product["specs"].values())[:3],
                "usage": product["usage_scenarios"],
                "safety_tips": product["safety_tips"],
            },
            "matched_products": [
                {
                    "product_id": product["id"],
                    "name": product["name"],
                    "price": product["price"],
                    "similarity": 0.95,
                    "image": product["images"][0],
                }
            ],
            "needs_more_images": False,
            "thumbnail": product["images"][0],
            "item_name": product["name"],
            "source": source,
            "created_at": utcnow(),
        }
        self.recognitions[recognition_id] = record
        return record

    def list_recognitions(self, user_id: int, *, page: int, limit: int) -> dict:
        items = [
            item for item in self.recognitions.values() if item["user_id"] == user_id
        ]
        items.sort(key=lambda item: item["created_at"], reverse=True)
        total = len(items)
        start = (page - 1) * limit
        end = start + limit
        return {
            "total": total,
            "records": [
                {
                    "recognition_id": item["recognition_id"],
                    "thumbnail": item["thumbnail"],
                    "item_name": item["item_name"],
                    "created_at": item["created_at"],
                }
                for item in items[start:end]
            ],
        }

    def add_recognition_feedback(
        self,
        user_id: int,
        *,
        recognition_id: str,
        feedback_type: str,
        comment: str | None,
        correct_product_id: int | None,
    ) -> None:
        if recognition_id not in self.recognitions:
            raise BusinessError(status_code=404, code=404, message="资源不存在")
        self.recognition_feedback.append(
            {
                "recognition_id": recognition_id,
                "user_id": user_id,
                "feedback_type": feedback_type,
                "comment": comment,
                "correct_product_id": correct_product_id,
                "created_at": utcnow(),
            }
        )

    def chat(self, *, user_id: int, question: str, session_id: str | None) -> dict:
        session_id = session_id or f"session_{uuid.uuid4().hex[:8]}"
        product = self._best_product_for_question(question)
        citations = [
            item
            for item in self.knowledge
            if product["id"] in item["product_ids"]
        ] or self.knowledge[:1]
        answer = (
            f"{product['name']} 推荐型号为 {product['model_no']}。"
            f" 适配范围主要包括 {', '.join(product['compatibility'])}，"
            "建议结合工时、磨损和接口规格一起确认。"
        )
        message_id = f"msg_{uuid.uuid4().hex[:8]}"
        conversation = self.conversations.get(session_id)
        if conversation is None:
            conversation = {
                "user_id": user_id,
                "session_id": session_id,
                "messages": [],
                "created_at": utcnow(),
                "updated_at": utcnow(),
            }
            self.conversations[session_id] = conversation
        conversation["messages"].append(
            {
                "message_id": message_id,
                "question": question,
                "answer": answer,
                "citations": citations,
                "recommended_products": [product],
                "created_at": utcnow(),
            }
        )
        conversation["updated_at"] = utcnow()
        return {
            "answer": answer,
            "citations": [
                {
                    "knowledge_id": item["id"],
                    "title": item["title"],
                    "snippet": item["snippet"],
                }
                for item in citations
            ],
            "recommended_products": [
                {
                    "product_id": product["id"],
                    "name": product["name"],
                    "price": product["price"],
                    "image": product["images"][0],
                }
            ],
            "session_id": session_id,
            "message_id": message_id,
        }

    def list_conversations(self, user_id: int, *, page: int, limit: int) -> dict:
        items = [
            convo for convo in self.conversations.values() if convo["user_id"] == user_id
        ]
        items.sort(key=lambda item: item["updated_at"], reverse=True)
        total = len(items)
        start = (page - 1) * limit
        end = start + limit
        sessions = []
        for convo in items[start:end]:
            last_message = convo["messages"][-1] if convo["messages"] else None
            sessions.append(
                {
                    "session_id": convo["session_id"],
                    "last_question": last_message["question"] if last_message else "",
                    "updated_at": convo["updated_at"],
                }
            )
        return {"total": total, "sessions": sessions}

    def add_conversation_feedback(
        self,
        user_id: int,
        *,
        session_id: str,
        message_id: str,
        rating: int,
        comment: str | None,
    ) -> None:
        conversation = self.conversations.get(session_id)
        if conversation is None:
            raise BusinessError(status_code=404, code=404, message="资源不存在")
        known_ids = {message["message_id"] for message in conversation["messages"]}
        if message_id not in known_ids:
            raise BusinessError(status_code=404, code=404, message="资源不存在")
        self.conversation_feedback.append(
            {
                "user_id": user_id,
                "session_id": session_id,
                "message_id": message_id,
                "rating": rating,
                "comment": comment,
                "created_at": utcnow(),
            }
        )

    def add_favorite(self, user_id: int, product_id: int) -> None:
        self.get_product(product_id)
        favorites = self.favorite_product_ids.setdefault(user_id, set())
        if product_id in favorites:
            raise BusinessError(status_code=409, code=409, message="重复操作")
        favorites.add(product_id)

    def remove_favorite(self, user_id: int, product_id: int) -> None:
        favorites = self.favorite_product_ids.setdefault(user_id, set())
        favorites.discard(product_id)

    def list_favorites(self, user_id: int, *, page: int, limit: int) -> dict:
        ids = list(self.favorite_product_ids.get(user_id, set()))
        products = [self.get_product(product_id) for product_id in ids]
        total = len(products)
        start = (page - 1) * limit
        end = start + limit
        return {
            "total": total,
            "products": [
                {
                    "id": item["id"],
                    "name": item["name"],
                    "price": item["price"],
                    "image": item["images"][0],
                }
                for item in products[start:end]
            ],
        }

    def upload_document(self, *, filename: str, product_ids: list[int]) -> dict:
        knowledge_ids = []
        for _ in range(5):
            knowledge_ids.append(self.next_knowledge_id)
            self.next_knowledge_id += 1
        job = self._create_job(
            job_type="upload-document",
            source_file=filename,
            total_count=len(knowledge_ids),
            success_count=len(knowledge_ids),
            failed_count=0,
            status="completed",
        )
        return {
            "message": f"成功提取 {len(knowledge_ids)} 条知识",
            "knowledge_ids": knowledge_ids,
            "job_id": job["id"],
            "product_ids": product_ids,
        }

    def reindex(self, *, knowledge_ids: list[int], rebuild_mode: str) -> dict:
        job = self._create_job(
            job_type="reindex",
            source_file=None,
            total_count=len(knowledge_ids),
            success_count=len(knowledge_ids),
            failed_count=0,
            status="completed",
        )
        return {
            "job_id": job["id"],
            "status": job["status"],
            "rebuild_mode": rebuild_mode,
        }

    def get_job(self, job_id: int) -> dict:
        job = self.knowledge_jobs.get(job_id)
        if job is None:
            raise BusinessError(status_code=404, code=404, message="资源不存在")
        return job

    def _create_job(
        self,
        *,
        job_type: str,
        source_file: str | None,
        total_count: int,
        success_count: int,
        failed_count: int,
        status: str,
    ) -> dict:
        now = utcnow()
        job = {
            "id": self.next_job_id,
            "job_type": job_type,
            "source_file": source_file,
            "status": status,
            "total_count": total_count,
            "success_count": success_count,
            "failed_count": failed_count,
            "error_summary": None,
            "created_at": now,
            "updated_at": now,
        }
        self.knowledge_jobs[job["id"]] = job
        self.next_job_id += 1
        return job

    def _detect_search_type(self, query: str) -> str:
        return "model" if any(char.isdigit() for char in query) else "keyword"

    def _match_reason(self, search_type: str) -> str:
        return {
            "model": "型号匹配 + 适配机型匹配",
            "keyword": "关键词匹配",
            "semantic": "语义近似匹配",
        }.get(search_type, "综合排序")

    def _best_product_for_question(self, question: str) -> dict:
        lowered = question.lower()
        for product in self.products:
            haystack = " ".join(
                [
                    product["name"],
                    product["brand"],
                    product["model_no"],
                    *product["keywords"],
                    *product["compatibility"],
                ]
            ).lower()
            if any(part in haystack for part in lowered.split()):
                return product
        return self.products[0]
