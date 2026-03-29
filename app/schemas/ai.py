from datetime import datetime

from pydantic import BaseModel


class RecognitionResultData(BaseModel):
    item_name: str
    category: str
    description: str
    features: list[str]
    usage: str
    safety_tips: list[str]


class MatchedProduct(BaseModel):
    product_id: int
    name: str
    price: float
    similarity: float
    image: str


class RecognitionResponseData(BaseModel):
    recognition_id: str
    image_url: str
    confidence: float
    result: RecognitionResultData
    matched_products: list[MatchedProduct]
    needs_more_images: bool


class RecognitionListItem(BaseModel):
    recognition_id: str
    thumbnail: str
    item_name: str
    created_at: datetime


class RecognitionListData(BaseModel):
    total: int
    records: list[RecognitionListItem]


class RecognitionFeedbackRequest(BaseModel):
    feedback_type: str
    comment: str | None = None
    correct_product_id: int | None = None


class Citation(BaseModel):
    knowledge_id: int
    title: str
    snippet: str


class RecommendedProduct(BaseModel):
    product_id: int
    name: str
    price: float
    image: str


class RagChatRequest(BaseModel):
    question: str
    session_id: str | None = None


class RagChatData(BaseModel):
    answer: str
    citations: list[Citation]
    recommended_products: list[RecommendedProduct]
    session_id: str
    message_id: str


class ConversationListItem(BaseModel):
    session_id: str
    last_question: str
    updated_at: datetime


class ConversationListData(BaseModel):
    total: int
    sessions: list[ConversationListItem]


class ConversationMessageData(BaseModel):
    message_id: str
    role: str
    content: str
    citations: list[Citation] = []
    recommended_products: list[RecommendedProduct] = []
    created_at: datetime


class ConversationDetailData(BaseModel):
    session_id: str
    title: str | None = None
    updated_at: datetime
    messages: list[ConversationMessageData]


class ConversationFeedbackRequest(BaseModel):
    message_id: str
    rating: int
    comment: str | None = None
