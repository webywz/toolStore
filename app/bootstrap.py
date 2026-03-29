from __future__ import annotations

from sqlalchemy import select

from app.core.security import hash_password
from app.models.entities import AIConversation, AIConversationMessage, AIRecognition, Category, Product, ProductKnowledge, SearchHistory, User, UserFavorite
from app.database import SessionLocal


def seed_database() -> None:
    with SessionLocal() as session:
        existing_user = session.scalar(select(User).limit(1))
        if existing_user is not None:
            return

        categories = [
            Category(id=1, name="挂机配件", parent_id=None, level=1, sort_order=1, icon_url="https://oss.example.com/icons/outboard.png"),
            Category(id=11, name="滤芯", parent_id=1, level=2, sort_order=1, icon_url=None),
            Category(id=12, name="火花塞", parent_id=1, level=2, sort_order=2, icon_url=None),
            Category(id=2, name="冷却系统", parent_id=None, level=1, sort_order=2, icon_url="https://oss.example.com/icons/cooling.png"),
            Category(id=21, name="叶轮", parent_id=2, level=2, sort_order=1, icon_url=None),
            Category(id=22, name="泵体", parent_id=2, level=2, sort_order=2, icon_url=None),
            Category(id=3, name="通用紧固件", parent_id=None, level=1, sort_order=3, icon_url="https://oss.example.com/icons/fastener.png"),
            Category(id=31, name="螺丝", parent_id=3, level=2, sort_order=1, icon_url=None),
            Category(id=32, name="卡箍", parent_id=3, level=2, sort_order=2, icon_url=None),
        ]
        session.add_all(categories)

        products = [
            Product(
                id=101,
                category_id=1,
                name="雅马哈F40机油滤芯",
                brand="Yamaha",
                model_no="69J-13440-03",
                description="适用于雅马哈 F40/F50/F60 挂机的常规保养机油滤芯。",
                price=89.0,
                images=["https://oss.example.com/products/101-1.jpg", "https://oss.example.com/products/101-2.jpg"],
                specs={"型号": "69J-13440-03", "更换周期": "100小时", "材质": "复合滤纸"},
                compatibility=["F40", "F50", "F60"],
                usage_scenarios="挂机保养、定期更换",
                safety_tips=["检查 O 型圈", "按保养周期更换"],
                keywords=["雅马哈", "F40", "机油滤芯"],
                status="active",
            ),
            Product(
                id=102,
                category_id=1,
                name="铃木DF60火花塞",
                brand="Suzuki",
                model_no="NGK DPR6EA-9",
                description="适用于铃木 DF60/DF70 挂机，适合启动性能恢复。",
                price=42.0,
                images=["https://oss.example.com/products/102.jpg"],
                specs={"型号": "NGK DPR6EA-9", "间隙": "0.9 mm", "扭矩建议": "18 N·m"},
                compatibility=["DF60", "DF70"],
                usage_scenarios="点火维护、冷启动排查",
                safety_tips=["避免热机状态拆装", "安装前清洁螺纹孔"],
                keywords=["铃木", "DF60", "火花塞"],
                status="active",
            ),
            Product(
                id=103,
                category_id=2,
                name="本田BF90水泵叶轮",
                brand="Honda",
                model_no="19210-ZW1-B04",
                description="适用于 BF75/BF90 冷却系统维护，更换周期明确。",
                price=168.0,
                images=["https://oss.example.com/products/103.jpg"],
                specs={"型号": "19210-ZW1-B04", "材质": "耐海水橡胶", "建议周期": "每季检查"},
                compatibility=["BF75", "BF90"],
                usage_scenarios="冷却流量不足、年度保养",
                safety_tips=["检查泵壳磨损", "安装时涂少量润滑剂"],
                keywords=["本田", "BF90", "叶轮"],
                status="active",
            ),
            Product(
                id=104,
                category_id=3,
                name="316不锈钢螺丝 M6×20",
                brand="MarineFix",
                model_no="MF-M6-20",
                description="船用耐腐蚀 316 不锈钢螺丝，适用于常见固定场景。",
                price=12.0,
                images=["https://oss.example.com/products/104.jpg"],
                specs={"规格": "M6×20", "材质": "316 不锈钢", "包装": "10只/包"},
                compatibility=["通用"],
                usage_scenarios="船体固定、挂机安装",
                safety_tips=["避免过度拧紧", "定期检查腐蚀情况"],
                keywords=["316", "不锈钢螺丝", "M6"],
                status="active",
            ),
        ]
        session.add_all(products)

        knowledge = [
            ProductKnowledge(
                id=1001,
                product_ids=[101],
                content_type="manual",
                title="雅马哈F40机油滤芯适配",
                content="适用机型：F40、F50A、F60；推荐型号 69J-13440-03。",
                engine_models=["F40", "F50A", "F60"],
                source_type="seed",
                source_ref="manual:f40",
                content_hash="seed_1001",
                vector_id="vec_1001",
            ),
            ProductKnowledge(
                id=1002,
                product_ids=[102],
                content_type="manual",
                title="DF60 点火维护建议",
                content="建议火花塞间隙 0.9 mm，电极烧蚀明显时直接更换。",
                engine_models=["DF60", "DF70"],
                source_type="seed",
                source_ref="manual:df60",
                content_hash="seed_1002",
                vector_id="vec_1002",
            ),
            ProductKnowledge(
                id=1003,
                product_ids=[103],
                content_type="manual",
                title="叶轮老化检查",
                content="叶轮出现裂纹、变形或冷却流量下降时应优先更换。",
                engine_models=["BF75", "BF90"],
                source_type="seed",
                source_ref="manual:impeller",
                content_hash="seed_1003",
                vector_id="vec_1003",
            ),
        ]
        session.add_all(knowledge)

        user = User(
            id=1,
            phone="13800138000",
            password_hash=hash_password("123456"),
            nickname="张三",
            avatar_url="https://oss.example.com/avatar.jpg",
        )
        session.add(user)
        session.flush()
        session.add_all(
            [
                SearchHistory(user_id=1, query_text="F40 机油滤芯", search_type="model"),
                SearchHistory(user_id=1, query_text="O 型圈", search_type="keyword"),
                UserFavorite(user_id=1, product_id=101),
                AIRecognition(
                    recognition_id="rec_seed_001",
                    user_id=1,
                    image_url="https://oss.example.com/uploads/sample-f40.jpg",
                    source="camera",
                    confidence=0.86,
                    recognition_result={
                        "item_name": "雅马哈F40机油滤芯",
                        "category": "挂机配件",
                        "description": "这是一款适用于雅马哈挂机的机油滤芯。",
                        "features": ["复合滤纸", "耐压结构", "原厂适配"],
                        "usage": "挂机保养、定期更换",
                        "safety_tips": ["检查 O 型圈", "按保养周期更换"],
                    },
                    matched_products=[
                        {
                            "product_id": 101,
                            "name": "雅马哈F40机油滤芯",
                            "price": 89.0,
                            "similarity": 0.95,
                            "image": "https://oss.example.com/products/101-1.jpg",
                        }
                    ],
                    needs_more_images=False,
                ),
            ]
        )

        conversation = AIConversation(id=1, user_id=1, session_id="session_123", title="F40 用什么机油滤芯？")
        session.add(conversation)
        session.flush()
        session.add_all(
            [
                AIConversationMessage(
                    conversation_id=conversation.id,
                    message_id="msg_seed_question",
                    role="user",
                    content="F40 用什么机油滤芯？",
                ),
                AIConversationMessage(
                    conversation_id=conversation.id,
                    message_id="msg_seed_answer",
                    role="assistant",
                    content="雅马哈 F40 挂机推荐使用 69J-13440-03 机油滤芯。",
                    citations=[
                        {
                            "knowledge_id": 1001,
                            "title": "雅马哈F40机油滤芯适配",
                            "snippet": "适用机型：F40、F50A、F60；推荐型号 69J-13440-03。",
                        }
                    ],
                    recommended_products=[
                        {
                            "product_id": 101,
                            "name": "雅马哈F40机油滤芯",
                            "price": 89.0,
                            "image": "https://oss.example.com/products/101-1.jpg",
                        }
                    ],
                ),
            ]
        )
        session.commit()
