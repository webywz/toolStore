from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import re
import uuid

from sqlalchemy import Select, func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.exceptions import BusinessError
from app.core.security import create_access_token, hash_password, verify_password
from app.models.entities import (
    AIChatFeedback,
    AIConversation,
    AIConversationMessage,
    AIRecognition,
    AIRecognitionFeedback,
    Category,
    KnowledgeJob,
    KnowledgeVersionSnapshot,
    Product,
    ProductKnowledge,
    SearchHistory,
    User,
    UserFavorite,
)
from app.services.knowledge_import_service import ParsedKnowledgeChunk, parse_document_chunks


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _to_float(value: object) -> float:
    if value is None:
        return 0.0
    return float(value)


def _tokenize_query(text: str) -> list[str]:
    return [token for token in re.split(r"[\s,，、/]+", text.lower().strip()) if token]


class DatabaseStore:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get_user_by_id(self, user_id: int) -> User | None:
        return self.session.get(User, user_id)

    def register_user(self, account: str, password: str, nickname: str) -> dict:
        existing = self.session.scalar(select(User).where(User.phone == account))
        if existing is not None:
            raise BusinessError(status_code=409, code=10003, message="账号已注册")
        user = User(
            phone=account,
            password_hash=hash_password(password),
            nickname=nickname,
            avatar_url=None,
        )
        self.session.add(user)
        self.session.commit()
        self.session.refresh(user)
        return {
            "user_id": user.id,
            "token": create_access_token(user.id),
            "nickname": user.nickname,
        }

    def login_user(self, account: str, password: str) -> dict:
        user = self.session.scalar(select(User).where(User.phone == account))
        if user is None:
            raise BusinessError(status_code=404, code=10001, message="用户不存在")
        if not verify_password(password, user.password_hash):
            raise BusinessError(status_code=401, code=10002, message="密码错误")
        return {
            "user_id": user.id,
            "token": create_access_token(user.id),
            "nickname": user.nickname,
        }

    def change_password(self, user_id: int, old_password: str, new_password: str) -> None:
        user = self.session.get(User, user_id)
        if user is None:
            raise BusinessError(status_code=404, code=10001, message="用户不存在")
        if not verify_password(old_password, user.password_hash):
            raise BusinessError(status_code=401, code=10002, message="原密码错误")
        user.password_hash = hash_password(new_password)
        self.session.commit()

    def reset_password(self, account: str, new_password: str) -> None:
        user = self.session.scalar(select(User).where(User.phone == account))
        if user is None:
            raise BusinessError(status_code=404, code=10001, message="用户不存在")
        user.password_hash = hash_password(new_password)
        self.session.commit()

    def _category_ids_for_filter(self, category_id: int | None) -> list[int] | None:
        if category_id is None:
            return None
        child_ids = self.session.scalars(select(Category.id).where(Category.parent_id == category_id)).all()
        return [category_id, *child_ids]

    def _product_base_query(self, category_id: int | None, keyword: str | None) -> Select[tuple[Product]]:
        stmt = (
            select(Product)
            .options(selectinload(Product.category))
            .where(Product.status == "active")
            .order_by(Product.created_at.desc(), Product.id.desc())
        )
        category_ids = self._category_ids_for_filter(category_id)
        if category_ids:
            stmt = stmt.where(Product.category_id.in_(category_ids))
        if keyword:
            pattern = f"%{keyword.strip()}%"
            stmt = stmt.where(
                or_(
                    Product.name.ilike(pattern),
                    Product.brand.ilike(pattern),
                    Product.model_no.ilike(pattern),
                    Product.description.ilike(pattern),
                )
            )
        return stmt

    def _serialize_product_list_item(self, product: Product) -> dict:
        category_name = product.category.name if product.category else ""
        return {
            "id": product.id,
            "name": product.name,
            "price": _to_float(product.price),
            "images": product.images or [],
            "category": category_name,
            "compatibility": product.compatibility or [],
        }

    def list_products(
        self,
        page: int = 1,
        limit: int = 20,
        category_id: int | None = None,
        keyword: str | None = None,
    ) -> dict:
        stmt = self._product_base_query(category_id=category_id, keyword=keyword)
        total = self.session.scalar(select(func.count()).select_from(stmt.subquery())) or 0
        items = self.session.scalars(stmt.offset((page - 1) * limit).limit(limit)).all()
        return {
            "total": total,
            "page": page,
            "limit": limit,
            "products": [self._serialize_product_list_item(product) for product in items],
        }

    def get_product(self, product_id: int) -> dict:
        product = self.session.scalar(
            select(Product).options(selectinload(Product.category)).where(Product.id == product_id)
        )
        if product is None or product.status != "active":
            raise BusinessError(status_code=404, code=20001, message="商品不存在")
        return {
            "id": product.id,
            "name": product.name,
            "category_id": product.category_id or 0,
            "brand": product.brand or "",
            "model": product.model_no or "",
            "category": product.category.name if product.category else "",
            "price": _to_float(product.price),
            "images": product.images or [],
            "description": product.description or "",
            "specs": product.specs or {},
            "compatibility": product.compatibility or [],
            "usage_scenarios": product.usage_scenarios or "",
            "safety_tips": product.safety_tips or [],
            "keywords": product.keywords or [],
            "created_at": product.created_at,
        }

    def list_categories(self) -> list[dict]:
        roots = self.session.scalars(
            select(Category)
            .options(selectinload(Category.children))
            .where(Category.parent_id.is_(None))
            .order_by(Category.sort_order.asc(), Category.id.asc())
        ).all()
        return [
            {
                "id": category.id,
                "name": category.name,
                "icon_url": category.icon_url,
                "children": [
                    {
                        "id": child.id,
                        "name": child.name,
                        "icon_url": child.icon_url,
                    }
                    for child in sorted(category.children, key=lambda item: (item.sort_order, item.id))
                ],
            }
            for category in roots
        ]

    def _resolve_search_type(self, query: str, search_type: str) -> str:
        if search_type != "auto":
            return search_type
        if re.search(r"[A-Za-z].*\d|\d.*[A-Za-z]", query):
            return "model"
        if len(query.strip()) >= 6:
            return "semantic"
        return "keyword"

    def intelligent_search(
        self,
        query: str,
        search_type: str,
        category_id: int | None = None,
        min_price: float | None = None,
        max_price: float | None = None,
        sort_by: str = "relevance",
        page: int = 1,
        limit: int = 10,
        user_id: int | None = None,
    ) -> dict:
        actual_type = self._resolve_search_type(query, search_type)
        stmt = select(Product).options(selectinload(Product.category)).where(Product.status == "active")
        if category_id is not None:
            stmt = stmt.where(Product.category_id == category_id)
        if min_price is not None:
            stmt = stmt.where(Product.price >= min_price)
        if max_price is not None:
            stmt = stmt.where(Product.price <= max_price)
        items = self.session.scalars(stmt).all()

        lowered_terms = [token for token in re.split(r"\s+", query.lower().strip()) if token]
        scored: list[tuple[float, Product, str]] = []
        for product in items:
            haystacks = [
                product.name.lower(),
                (product.brand or "").lower(),
                (product.model_no or "").lower(),
                (product.description or "").lower(),
                " ".join(item.lower() for item in (product.keywords or [])),
                " ".join(item.lower() for item in (product.compatibility or [])),
            ]
            score = 0.0
            reasons: list[str] = []
            for term in lowered_terms:
                if product.model_no and term in product.model_no.lower():
                    score += 0.45
                    reasons.append("型号匹配")
                if term in product.name.lower():
                    score += 0.35
                    reasons.append("名称匹配")
                if any(term in keyword.lower() for keyword in (product.keywords or [])):
                    score += 0.2
                    reasons.append("关键词匹配")
                if any(term in model.lower() for model in (product.compatibility or [])):
                    score += 0.18
                    reasons.append("适配机型匹配")
                if actual_type == "semantic" and any(term in text for text in haystacks):
                    score += 0.1
                    reasons.append("语义命中")
            if score > 0:
                reason_text = " + ".join(dict.fromkeys(reasons)) if reasons else "综合匹配"
                scored.append((min(score, 0.99), product, reason_text))

        if sort_by == "price_asc":
            scored.sort(key=lambda item: (_to_float(item[1].price), -item[0], item[1].id))
        elif sort_by == "price_desc":
            scored.sort(key=lambda item: (_to_float(item[1].price), item[0], item[1].id), reverse=True)
        elif sort_by == "newest":
            scored.sort(key=lambda item: (item[1].created_at, item[0], item[1].id), reverse=True)
        else:
            scored.sort(key=lambda item: (item[0], item[1].id), reverse=True)
        total = len(scored)
        paged = scored[(page - 1) * limit : page * limit]
        results = [
            {
                "product_id": product.id,
                "name": product.name,
                "price": _to_float(product.price),
                "image": (product.images or [""])[0],
                "score": round(score, 2),
                "match_reason": reason,
            }
            for score, product, reason in paged
        ]

        if user_id is not None:
            self.session.add(SearchHistory(user_id=user_id, query_text=query, search_type=actual_type))
            self.session.commit()

        return {
            "query": query,
            "search_type": actual_type,
            "total": total,
            "page": page,
            "limit": limit,
            "results": results,
        }

    def search_suggestions(self, q: str) -> list[str]:
        pattern = f"%{q.strip()}%"
        products = self.session.scalars(
            select(Product)
            .where(
                Product.status == "active",
                or_(Product.name.ilike(pattern), Product.model_no.ilike(pattern)),
            )
            .order_by(Product.id.asc())
            .limit(8)
        ).all()
        suggestions = [product.name for product in products]
        if not suggestions:
            suggestions = [f"{q} 机油滤芯", f"{q} 火花塞", f"{q} 保养套件"]
        return suggestions[:8]

    def get_search_histories(self, user_id: int) -> list[dict]:
        rows = self.session.scalars(
            select(SearchHistory)
            .where(SearchHistory.user_id == user_id)
            .order_by(SearchHistory.created_at.desc(), SearchHistory.id.desc())
            .limit(20)
        ).all()
        return [
            {
                "query_text": row.query_text,
                "search_type": row.search_type,
                "created_at": row.created_at,
            }
            for row in rows
        ]

    def _recognition_payload_for_product(self, product: Product) -> tuple[dict, list[dict]]:
        result = {
            "item_name": product.name,
            "category": product.category.name if product.category else "",
            "description": product.description or "",
            "features": list((product.specs or {}).values())[:3],
            "usage": product.usage_scenarios or "",
            "safety_tips": product.safety_tips or [],
        }
        matches = [
            {
                "product_id": product.id,
                "name": product.name,
                "price": _to_float(product.price),
                "similarity": 0.95,
                "image": (product.images or [""])[0],
            }
        ]
        return result, matches

    def _find_recognition_matches(self, recognition_result: dict, limit: int = 3) -> list[dict]:
        fields = [
            recognition_result.get("item_name", ""),
            recognition_result.get("category", ""),
            recognition_result.get("description", ""),
            recognition_result.get("usage", ""),
            " ".join(item for item in recognition_result.get("features", []) if item),
        ]
        terms = [token for token in _tokenize_query(" ".join(fields)) if len(token) >= 2]
        if not terms:
            return []

        products = self.session.scalars(
            select(Product).options(selectinload(Product.category)).where(Product.status == "active")
        ).all()
        scored: list[tuple[float, Product]] = []
        for product in products:
            haystacks = [
                product.name.lower(),
                (product.brand or "").lower(),
                (product.model_no or "").lower(),
                (product.description or "").lower(),
                " ".join(item.lower() for item in (product.keywords or [])),
                " ".join(item.lower() for item in (product.compatibility or [])),
                (product.category.name.lower() if product.category else ""),
            ]
            score = 0.0
            for term in terms:
                if term in product.name.lower():
                    score += 0.45
                if product.model_no and term in product.model_no.lower():
                    score += 0.3
                if any(term in field for field in haystacks):
                    score += 0.12
            if score > 0:
                scored.append((score, product))

        scored.sort(key=lambda item: (item[0], item[1].id), reverse=True)
        return [
            {
                "product_id": product.id,
                "name": product.name,
                "price": _to_float(product.price),
                "similarity": round(min(score, 0.99), 2),
                "image": (product.images or [""])[0],
            }
            for score, product in scored[:limit]
        ]

    def create_recognition(self, user_id: int, image_url: str, source: str, recognition_result: dict) -> dict:
        matches = self._find_recognition_matches(recognition_result)

        recognition = AIRecognition(
            recognition_id=f"rec_{uuid.uuid4().hex[:12]}",
            user_id=user_id,
            image_url=image_url,
            source=source,
            confidence=0.86,
            recognition_result=recognition_result,
            matched_products=matches,
            needs_more_images=False,
        )
        self.session.add(recognition)
        self.session.commit()
        self.session.refresh(recognition)
        return {
            "recognition_id": recognition.recognition_id,
            "image_url": recognition.image_url,
            "confidence": recognition.confidence or 0.0,
            "result": recognition.recognition_result,
            "matched_products": recognition.matched_products or [],
            "needs_more_images": recognition.needs_more_images,
        }

    def list_recognitions(self, user_id: int, page: int, limit: int) -> dict:
        stmt = (
            select(AIRecognition)
            .where(AIRecognition.user_id == user_id)
            .order_by(AIRecognition.created_at.desc(), AIRecognition.id.desc())
        )
        total = self.session.scalar(select(func.count()).select_from(stmt.subquery())) or 0
        rows = self.session.scalars(stmt.offset((page - 1) * limit).limit(limit)).all()
        records = [
            {
                "recognition_id": row.recognition_id,
                "thumbnail": row.image_url,
                "item_name": row.recognition_result.get("item_name", "未知商品"),
                "created_at": row.created_at,
            }
            for row in rows
        ]
        return {"total": total, "records": records}

    def add_recognition_feedback(
        self,
        user_id: int,
        recognition_id: str,
        feedback_type: str,
        comment: str | None,
        correct_product_id: int | None,
    ) -> None:
        recognition = self.session.scalar(select(AIRecognition).where(AIRecognition.recognition_id == recognition_id))
        if recognition is None:
            raise BusinessError(status_code=404, code=30001, message="AI 识别失败")
        product = None
        if correct_product_id is not None:
            product = self.session.get(Product, correct_product_id)
            if product is None:
                raise BusinessError(status_code=404, code=20001, message="商品不存在")
            matches = [item for item in (recognition.matched_products or []) if item.get("product_id") != product.id]
            matches.insert(
                0,
                {
                    "product_id": product.id,
                    "name": product.name,
                    "price": _to_float(product.price),
                    "similarity": 1.0,
                    "image": (product.images or [""])[0],
                },
            )
            recognition.matched_products = matches[:3]
            result = dict(recognition.recognition_result or {})
            result["corrected_product_name"] = product.name
            recognition.recognition_result = result
        self.session.add(
            AIRecognitionFeedback(
                recognition_id=recognition.id,
                user_id=user_id,
                feedback_type=feedback_type,
                comment=comment,
                correct_product_id=correct_product_id,
            )
        )
        if feedback_type == "need_more_images":
            recognition.needs_more_images = True
        self.session.commit()

    def _match_knowledge(self, question: str) -> list[ProductKnowledge]:
        terms = _tokenize_query(question)
        items = self.session.scalars(
            select(ProductKnowledge).where(ProductKnowledge.status == "active").order_by(ProductKnowledge.id.asc())
        ).all()
        scored: list[tuple[int, ProductKnowledge]] = []
        for item in items:
            text = f"{item.title} {item.content} {' '.join(item.engine_models or [])}".lower()
            score = sum(1 for term in terms if term in text)
            if score > 0:
                scored.append((score, item))
        scored.sort(key=lambda pair: (pair[0], pair[1].id), reverse=True)
        return [item for _, item in scored[:3]] or items[:1]

    def _search_knowledge_by_vector(self, question: str) -> list[ProductKnowledge]:
        from app.services.embedding_service import get_embedding_service
        from app.services.vector_store import get_vector_store

        query_vector = get_embedding_service().embed_text(question)
        knowledge_ids = get_vector_store().search(query_vector, limit=3)
        if not knowledge_ids:
            return []

        items = self.session.scalars(
            select(ProductKnowledge)
            .where(ProductKnowledge.status == "active", ProductKnowledge.id.in_(knowledge_ids))
            .order_by(ProductKnowledge.id.asc())
        ).all()
        by_id = {item.id: item for item in items}
        return [by_id[knowledge_id] for knowledge_id in knowledge_ids if knowledge_id in by_id]

    def _build_recommended_products(self, citations_knowledge: list[ProductKnowledge]) -> list[dict]:
        ordered_ids: list[int] = []
        for item in citations_knowledge:
            for product_id in item.product_ids or []:
                if product_id not in ordered_ids:
                    ordered_ids.append(product_id)
        if not ordered_ids:
            return []

        products = self.session.scalars(select(Product).where(Product.id.in_(ordered_ids))).all()
        by_id = {product.id: product for product in products}
        return [
            {
                "product_id": product.id,
                "name": product.name,
                "price": _to_float(product.price),
                "image": (product.images or [""])[0],
            }
            for product_id in ordered_ids
            if (product := by_id.get(product_id)) is not None
        ][:3]

    def _build_rag_answer(self, citations_knowledge: list[ProductKnowledge], recommended_products: list[dict]) -> str:
        if not citations_knowledge:
            return "当前知识库里还没有可用答案，请先补充文档或商品知识。"

        lead = citations_knowledge[0]
        conclusion = lead.content.strip().replace("\n", " ")
        reference_segments = []
        for item in citations_knowledge[1:3]:
            excerpt = item.content.strip().replace("\n", " ")[:80]
            reference_segments.append(f"{item.title}：{excerpt}")
        references = "；".join(reference_segments)

        segments = [f"结论：{conclusion}"]
        if references:
            segments.append(f"依据：{references}")
        if recommended_products:
            names = "、".join(item["name"] for item in recommended_products[:2])
            segments.append(f"建议：可优先核对 {names} 的型号、接口和更换周期。")
        return "\n".join(segment for segment in segments if segment)

    def chat(self, user_id: int, question: str, session_id: str | None) -> dict:
        session_key = session_id or f"session_{uuid.uuid4().hex[:12]}"
        conversation = self.session.scalar(
            select(AIConversation).options(selectinload(AIConversation.messages)).where(AIConversation.session_id == session_key)
        )
        if conversation is None:
            conversation = AIConversation(user_id=user_id, session_id=session_key, title=question[:50])
            self.session.add(conversation)
            self.session.flush()

        citations_knowledge = self._search_knowledge_by_vector(question)
        if not citations_knowledge:
            citations_knowledge = self._match_knowledge(question)

        citations = [
            {
                "knowledge_id": item.id,
                "title": item.title,
                "snippet": item.content[:120],
            }
            for item in citations_knowledge
        ]

        recommended_products = self._build_recommended_products(citations_knowledge)
        answer = self._build_rag_answer(citations_knowledge, recommended_products)

        user_message = AIConversationMessage(
            conversation_id=conversation.id,
            message_id=f"msg_{uuid.uuid4().hex[:12]}",
            role="user",
            content=question,
        )
        assistant_message = AIConversationMessage(
            conversation_id=conversation.id,
            message_id=f"msg_{uuid.uuid4().hex[:12]}",
            role="assistant",
            content=answer,
            citations=citations,
            recommended_products=recommended_products,
        )
        conversation.updated_at = utcnow()
        if conversation.title is None:
            conversation.title = question[:50]
        self.session.add_all([user_message, assistant_message])
        self.session.commit()
        self.session.refresh(assistant_message)
        return {
            "answer": assistant_message.content,
            "citations": assistant_message.citations or [],
            "recommended_products": assistant_message.recommended_products or [],
            "session_id": conversation.session_id,
            "message_id": assistant_message.message_id,
        }

    def list_conversations(self, user_id: int, page: int, limit: int) -> dict:
        stmt = (
            select(AIConversation)
            .options(selectinload(AIConversation.messages))
            .where(AIConversation.user_id == user_id)
            .order_by(AIConversation.updated_at.desc(), AIConversation.id.desc())
        )
        total = self.session.scalar(select(func.count()).select_from(stmt.subquery())) or 0
        conversations = self.session.scalars(stmt.offset((page - 1) * limit).limit(limit)).all()
        sessions = []
        for conversation in conversations:
            last_question = next(
                (message.content for message in reversed(conversation.messages) if message.role == "user"),
                conversation.title or "",
            )
            sessions.append(
                {
                    "session_id": conversation.session_id,
                    "last_question": last_question,
                    "updated_at": conversation.updated_at,
                }
            )
        return {"total": total, "sessions": sessions}

    def get_conversation_detail(self, user_id: int, session_id: str) -> dict:
        conversation = self.session.scalar(
            select(AIConversation)
            .options(selectinload(AIConversation.messages))
            .where(AIConversation.user_id == user_id, AIConversation.session_id == session_id)
        )
        if conversation is None:
            raise BusinessError(status_code=404, code=40001, message="会话不存在")

        return {
            "session_id": conversation.session_id,
            "title": conversation.title,
            "updated_at": conversation.updated_at,
            "messages": [
                {
                    "message_id": message.message_id,
                    "role": message.role,
                    "content": message.content,
                    "citations": message.citations or [],
                    "recommended_products": message.recommended_products or [],
                    "created_at": message.created_at,
                }
                for message in conversation.messages
            ],
        }

    def add_conversation_feedback(
        self,
        user_id: int,
        session_id: str,
        message_id: str,
        rating: int,
        comment: str | None,
    ) -> None:
        message = self.session.scalar(
            select(AIConversationMessage)
            .join(AIConversation, AIConversation.id == AIConversationMessage.conversation_id)
            .where(AIConversation.session_id == session_id, AIConversationMessage.message_id == message_id)
        )
        if message is None:
            raise BusinessError(status_code=404, code=40001, message="知识库检索失败")
        self.session.add(
            AIChatFeedback(
                conversation_message_id=message.id,
                user_id=user_id,
                rating=rating,
                comment=comment,
            )
        )
        self.session.commit()

    def add_favorite(self, user_id: int, product_id: int) -> None:
        if self.session.get(Product, product_id) is None:
            raise BusinessError(status_code=404, code=20001, message="商品不存在")
        existing = self.session.scalar(
            select(UserFavorite).where(UserFavorite.user_id == user_id, UserFavorite.product_id == product_id)
        )
        if existing is None:
            self.session.add(UserFavorite(user_id=user_id, product_id=product_id))
            self.session.commit()

    def remove_favorite(self, user_id: int, product_id: int) -> None:
        favorite = self.session.scalar(
            select(UserFavorite).where(UserFavorite.user_id == user_id, UserFavorite.product_id == product_id)
        )
        if favorite is not None:
            self.session.delete(favorite)
            self.session.commit()

    def list_favorites(self, user_id: int, page: int, limit: int) -> dict:
        stmt = (
            select(UserFavorite, Product)
            .join(Product, Product.id == UserFavorite.product_id)
            .where(UserFavorite.user_id == user_id)
            .order_by(UserFavorite.created_at.desc(), UserFavorite.id.desc())
        )
        total = self.session.scalar(
            select(func.count()).select_from(select(UserFavorite).where(UserFavorite.user_id == user_id).subquery())
        ) or 0
        rows = self.session.execute(stmt.offset((page - 1) * limit).limit(limit)).all()
        products = [
            {
                "id": product.id,
                "name": product.name,
                "price": _to_float(product.price),
                "image": (product.images or [""])[0],
            }
            for _, product in rows
        ]
        return {"total": total, "products": products}

    def _merge_product_ids(self, existing_ids: list[int] | None, new_ids: list[int]) -> list[int]:
        merged: list[int] = []
        for product_id in [*(existing_ids or []), *new_ids]:
            if product_id not in merged:
                merged.append(product_id)
        return merged

    def _upsert_knowledge_chunk(
        self,
        filename: str,
        product_ids: list[int],
        chunk: ParsedKnowledgeChunk,
    ) -> tuple[int, bool]:
        existing = self.session.scalar(
            select(ProductKnowledge).where(ProductKnowledge.content_hash == chunk.content_hash).limit(1)
        )
        if existing is not None:
            existing.product_ids = self._merge_product_ids(existing.product_ids, product_ids)
            existing.title = chunk.title
            existing.content = chunk.content
            existing.engine_models = chunk.engine_models
            existing.source_ref = filename
            existing.source_type = "upload"
            existing.status = "active"
            self.session.flush()
            return existing.id, False

        knowledge = ProductKnowledge(
            product_ids=product_ids,
            content_type="document",
            title=chunk.title,
            content=chunk.content,
            engine_models=chunk.engine_models,
            source_type="upload",
            source_ref=filename,
            content_hash=chunk.content_hash,
            vector_id=None,
        )
        self.session.add(knowledge)
        self.session.flush()
        self._snapshot_knowledge_version(knowledge)
        return knowledge.id, True

    def upload_document(self, filename: str, file_content: bytes, product_ids: list[int]) -> dict:
        chunks = parse_document_chunks(filename, file_content)
        knowledge_ids: list[int] = []
        created_count = 0
        reused_count = 0
        for chunk in chunks:
            knowledge_id, created = self._upsert_knowledge_chunk(filename, product_ids, chunk)
            knowledge_ids.append(knowledge_id)
            if created:
                created_count += 1
            else:
                reused_count += 1
        self.session.commit()
        return {
            "message": f"成功导入 {created_count} 条知识，复用 {reused_count} 条已有片段",
            "knowledge_ids": knowledge_ids,
        }

    def _serialize_knowledge_item(self, knowledge: ProductKnowledge) -> dict:
        return {
            "id": knowledge.id,
            "title": knowledge.title,
            "content": knowledge.content,
            "product_ids": knowledge.product_ids or [],
            "engine_models": knowledge.engine_models or [],
            "source_ref": knowledge.source_ref,
            "source_type": knowledge.source_type,
            "version": knowledge.version or 1,
            "status": knowledge.status,
            "created_at": knowledge.created_at,
            "updated_at": knowledge.updated_at,
        }

    def _serialize_knowledge_version(self, snapshot: KnowledgeVersionSnapshot) -> dict:
        return {
            "id": snapshot.id,
            "knowledge_id": snapshot.knowledge_id,
            "version": snapshot.version,
            "title": snapshot.title,
            "content": snapshot.content,
            "product_ids": snapshot.product_ids or [],
            "engine_models": snapshot.engine_models or [],
            "source_ref": snapshot.source_ref,
            "source_type": snapshot.source_type,
            "status": snapshot.status,
            "created_at": snapshot.created_at,
        }

    def _snapshot_knowledge_version(self, knowledge: ProductKnowledge) -> KnowledgeVersionSnapshot:
        existing = self.session.scalar(
            select(KnowledgeVersionSnapshot)
            .where(
                KnowledgeVersionSnapshot.knowledge_id == knowledge.id,
                KnowledgeVersionSnapshot.version == (knowledge.version or 1),
            )
            .limit(1)
        )
        if existing is not None:
            existing.title = knowledge.title
            existing.content = knowledge.content
            existing.product_ids = knowledge.product_ids or []
            existing.engine_models = knowledge.engine_models or []
            existing.source_ref = knowledge.source_ref
            existing.source_type = knowledge.source_type
            existing.status = knowledge.status
            return existing
        snapshot = KnowledgeVersionSnapshot(
            knowledge_id=knowledge.id,
            version=knowledge.version or 1,
            title=knowledge.title,
            content=knowledge.content,
            product_ids=knowledge.product_ids or [],
            engine_models=knowledge.engine_models or [],
            source_ref=knowledge.source_ref,
            source_type=knowledge.source_type,
            status=knowledge.status,
        )
        self.session.add(snapshot)
        self.session.flush()
        return snapshot

    def list_knowledge_items(self, page: int, limit: int, keyword: str | None = None) -> dict:
        stmt = select(ProductKnowledge).order_by(ProductKnowledge.updated_at.desc(), ProductKnowledge.id.desc())
        if keyword:
            pattern = f"%{keyword.strip()}%"
            stmt = stmt.where(
                or_(
                    ProductKnowledge.title.ilike(pattern),
                    ProductKnowledge.content.ilike(pattern),
                    ProductKnowledge.source_ref.ilike(pattern),
                )
            )
        total = self.session.scalar(select(func.count()).select_from(stmt.subquery())) or 0
        rows = self.session.scalars(stmt.offset((page - 1) * limit).limit(limit)).all()
        return {"total": total, "items": [self._serialize_knowledge_item(item) for item in rows]}

    def update_knowledge_item(self, knowledge_id: int, payload: dict) -> dict:
        knowledge = self.session.get(ProductKnowledge, knowledge_id)
        if knowledge is None:
            raise BusinessError(status_code=404, code=40001, message="知识片段不存在")
        knowledge.title = payload["title"]
        knowledge.content = payload["content"]
        knowledge.product_ids = payload.get("product_ids", [])
        knowledge.engine_models = payload.get("engine_models", [])
        knowledge.content_hash = hashlib.sha256(
            f"{knowledge.source_ref or knowledge.title}:{knowledge.content}".encode("utf-8")
        ).hexdigest()
        knowledge.version = (knowledge.version or 0) + 1
        knowledge.status = "active"
        self._snapshot_knowledge_version(knowledge)
        self.session.commit()
        self.session.refresh(knowledge)
        return self._serialize_knowledge_item(knowledge)

    def list_knowledge_versions(self, knowledge_id: int) -> dict:
        knowledge = self.session.get(ProductKnowledge, knowledge_id)
        if knowledge is None:
            raise BusinessError(status_code=404, code=40001, message="知识片段不存在")
        rows = self.session.scalars(
            select(KnowledgeVersionSnapshot)
            .where(KnowledgeVersionSnapshot.knowledge_id == knowledge_id)
            .order_by(KnowledgeVersionSnapshot.version.desc(), KnowledgeVersionSnapshot.id.desc())
        ).all()
        if not rows:
            self._snapshot_knowledge_version(knowledge)
            self.session.commit()
            rows = self.session.scalars(
                select(KnowledgeVersionSnapshot)
                .where(KnowledgeVersionSnapshot.knowledge_id == knowledge_id)
                .order_by(KnowledgeVersionSnapshot.version.desc(), KnowledgeVersionSnapshot.id.desc())
            ).all()
        return {
            "total": len(rows),
            "versions": [self._serialize_knowledge_version(item) for item in rows],
        }

    def _reindex_knowledge_rows(
        self,
        rows: list[ProductKnowledge],
        rebuild_mode: str,
        *,
        bump_version: bool,
    ) -> tuple[int, int, list[str]]:
        from app.services.embedding_service import get_embedding_service
        from app.services.vector_store import get_vector_store

        embedding = get_embedding_service()
        vector_store = get_vector_store()
        if rebuild_mode == "full":
            vector_store.reset()

        errors: list[str] = []
        success_count = 0
        failed_count = 0

        for knowledge in rows:
            try:
                vector = embedding.embed_text(f"{knowledge.title}\n{knowledge.content}")
                vector_store.upsert(knowledge.id, vector)
                knowledge.vector_id = f"vec_{knowledge.id}"
                if bump_version:
                    knowledge.version = (knowledge.version or 0) + 1
                knowledge.status = "active"
                success_count += 1
            except Exception as exc:
                failed_count += 1
                errors.append(f"知识 {knowledge.id} 重建失败: {exc}")
        return success_count, failed_count, errors

    def rollback_knowledge_item(self, knowledge_id: int, target_version: int) -> dict:
        knowledge = self.session.get(ProductKnowledge, knowledge_id)
        if knowledge is None:
            raise BusinessError(status_code=404, code=40001, message="知识片段不存在")
        snapshot = self.session.scalar(
            select(KnowledgeVersionSnapshot)
            .where(
                KnowledgeVersionSnapshot.knowledge_id == knowledge_id,
                KnowledgeVersionSnapshot.version == target_version,
            )
            .limit(1)
        )
        if snapshot is None:
            raise BusinessError(status_code=404, code=40001, message="目标版本不存在")
        knowledge.title = snapshot.title
        knowledge.content = snapshot.content
        knowledge.product_ids = snapshot.product_ids or []
        knowledge.engine_models = snapshot.engine_models or []
        knowledge.source_ref = snapshot.source_ref
        knowledge.source_type = snapshot.source_type
        knowledge.status = "active"
        knowledge.content_hash = hashlib.sha256(
            f"{knowledge.source_ref or knowledge.title}:{knowledge.content}".encode("utf-8")
        ).hexdigest()
        knowledge.version = (knowledge.version or 0) + 1
        self._snapshot_knowledge_version(knowledge)
        success_count, failed_count, errors = self._reindex_knowledge_rows(
            [knowledge],
            "incremental",
            bump_version=False,
        )
        if failed_count > 0 or success_count == 0:
            raise BusinessError(
                status_code=500,
                code=40003,
                message=errors[0] if errors else "知识片段回滚后重建失败",
            )
        self.session.commit()
        self.session.refresh(knowledge)
        return self._serialize_knowledge_item(knowledge)

    def delete_knowledge_item(self, knowledge_id: int) -> None:
        knowledge = self.session.get(ProductKnowledge, knowledge_id)
        if knowledge is None:
            raise BusinessError(status_code=404, code=40001, message="知识片段不存在")
        self.session.delete(knowledge)
        self.session.commit()

    def delete_knowledge_items(self, knowledge_ids: list[int]) -> int:
        ids = [knowledge_id for knowledge_id in knowledge_ids if knowledge_id > 0]
        if not ids:
            raise BusinessError(status_code=422, code=40002, message="请选择要删除的知识片段")
        rows = self.session.scalars(select(ProductKnowledge).where(ProductKnowledge.id.in_(ids))).all()
        if not rows:
            raise BusinessError(status_code=404, code=40001, message="知识片段不存在")
        deleted = 0
        for row in rows:
            self.session.delete(row)
            deleted += 1
        self.session.commit()
        return deleted

    def reindex(self, knowledge_ids: list[int], rebuild_mode: str) -> dict:
        id_filter = knowledge_ids or self.session.scalars(
            select(ProductKnowledge.id).where(ProductKnowledge.status == "active").order_by(ProductKnowledge.id.asc())
        ).all()
        if not id_filter:
            raise BusinessError(status_code=404, code=40001, message="没有可重建的知识片段")

        rows = self.session.scalars(
            select(ProductKnowledge)
            .where(ProductKnowledge.status == "active", ProductKnowledge.id.in_(id_filter))
            .order_by(ProductKnowledge.id.asc())
        ).all()
        if not rows:
            raise BusinessError(status_code=404, code=40001, message="没有可重建的知识片段")

        job = KnowledgeJob(
            job_type="reindex",
            status="running",
            total_count=len(rows),
            success_count=0,
            failed_count=0,
            error_summary=None,
            source_file=None,
        )
        self.session.add(job)
        self.session.commit()
        self.session.refresh(job)
        success_count, failed_count, errors = self._reindex_knowledge_rows(
            rows,
            rebuild_mode,
            bump_version=True,
        )

        job.success_count = success_count
        job.failed_count = failed_count
        job.status = "completed" if failed_count == 0 else "partial"
        job.error_summary = "\n".join(errors[:5]) if errors else None
        self.session.commit()
        self.session.refresh(job)
        return {
            "job_id": job.id,
            "status": job.status,
            "rebuild_mode": rebuild_mode,
        }

    def list_jobs(self, page: int, limit: int) -> dict:
        stmt = select(KnowledgeJob).order_by(KnowledgeJob.created_at.desc(), KnowledgeJob.id.desc())
        total = self.session.scalar(select(func.count()).select_from(stmt.subquery())) or 0
        jobs = self.session.scalars(stmt.offset((page - 1) * limit).limit(limit)).all()
        return {
            "total": total,
            "jobs": [self.get_job(job.id) for job in jobs],
        }

    def get_job(self, job_id: int) -> dict:
        job = self.session.get(KnowledgeJob, job_id)
        if job is None:
            raise BusinessError(status_code=404, code=40001, message="知识库检索失败")
        return {
            "id": job.id,
            "job_type": job.job_type,
            "source_file": job.source_file,
            "status": job.status,
            "total_count": job.total_count,
            "success_count": job.success_count,
            "failed_count": job.failed_count,
            "error_summary": job.error_summary,
            "created_at": job.created_at,
            "updated_at": job.updated_at,
        }

    def create_category(self, name: str, parent_id: int | None, icon_url: str | None) -> dict:
        level = 1
        if parent_id is not None:
            parent = self.session.get(Category, parent_id)
            if parent is None:
                raise BusinessError(status_code=404, code=20002, message="分类不存在")
            level = parent.level + 1
        next_sort = (self.session.scalar(select(func.max(Category.sort_order))) or 0) + 1
        category = Category(name=name, parent_id=parent_id, level=level, sort_order=next_sort, icon_url=icon_url)
        self.session.add(category)
        self.session.commit()
        self.session.refresh(category)
        return {
            "id": category.id,
            "name": category.name,
            "parent_id": category.parent_id,
            "level": category.level,
            "icon_url": category.icon_url,
        }

    def create_product(self, payload: dict) -> dict:
        category = self.session.get(Category, payload["category_id"])
        if category is None:
            raise BusinessError(status_code=404, code=20002, message="分类不存在")
        product = Product(
            category_id=payload["category_id"],
            name=payload["name"],
            brand=payload.get("brand"),
            model_no=payload.get("model_no"),
            description=payload.get("description"),
            price=payload.get("price", 0),
            images=payload.get("images", []),
            specs=payload.get("specs", {}),
            compatibility=payload.get("compatibility", []),
            usage_scenarios=payload.get("usage_scenarios"),
            safety_tips=payload.get("safety_tips", []),
            keywords=payload.get("keywords", []),
            status="active",
        )
        self.session.add(product)
        self.session.commit()
        self.session.refresh(product)
        return {
            "id": product.id,
            "name": product.name,
            "category_id": product.category_id,
        }

    def update_product(self, product_id: int, payload: dict) -> dict:
        product = self.session.get(Product, product_id)
        if product is None or product.status != "active":
            raise BusinessError(status_code=404, code=20001, message="商品不存在")
        category = self.session.get(Category, payload["category_id"])
        if category is None:
            raise BusinessError(status_code=404, code=20002, message="分类不存在")

        product.category_id = payload["category_id"]
        product.name = payload["name"]
        product.brand = payload.get("brand")
        product.model_no = payload.get("model_no")
        product.description = payload.get("description")
        product.price = payload.get("price", 0)
        product.images = payload.get("images", [])
        product.specs = payload.get("specs", {})
        product.compatibility = payload.get("compatibility", [])
        product.usage_scenarios = payload.get("usage_scenarios")
        product.safety_tips = payload.get("safety_tips", [])
        product.keywords = payload.get("keywords", [])
        self.session.commit()
        self.session.refresh(product)
        return {
            "id": product.id,
            "name": product.name,
            "category_id": product.category_id,
        }

    def delete_product(self, product_id: int) -> None:
        product = self.session.get(Product, product_id)
        if product is None or product.status != "active":
            raise BusinessError(status_code=404, code=20001, message="商品不存在")
        product.status = "inactive"
        self.session.commit()

    def update_user_profile(self, user_id: int, nickname: str, avatar_url: str | None) -> dict:
        user = self.session.get(User, user_id)
        if user is None:
            raise BusinessError(status_code=404, code=10001, message="用户不存在")
        user.nickname = nickname
        user.avatar_url = avatar_url
        self.session.commit()
        self.session.refresh(user)
        return {
            "id": user.id,
            "account": user.phone,
            "nickname": user.nickname,
            "avatar_url": user.avatar_url,
        }

    def update_user_avatar(self, user_id: int, avatar_url: str) -> dict:
        user = self.session.get(User, user_id)
        if user is None:
            raise BusinessError(status_code=404, code=10001, message="用户不存在")
        user.avatar_url = avatar_url
        self.session.commit()
        self.session.refresh(user)
        return {
            "id": user.id,
            "account": user.phone,
            "nickname": user.nickname,
            "avatar_url": user.avatar_url,
        }
