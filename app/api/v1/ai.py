from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile

from app.core.deps import get_current_user, get_store
from app.models.entities import User
from app.schemas.ai import (
    ConversationDetailData,
    ConversationFeedbackRequest,
    ConversationListData,
    ConversationListItem,
    ConversationMessageData,
    RagChatData,
    RagChatRequest,
    RecognitionFeedbackRequest,
    RecognitionListData,
    RecognitionListItem,
    RecognitionResponseData,
)
from app.schemas.common import MessagePayload, SuccessResponse
from app.services.claude_service import get_claude_service
from app.services.db_store import DatabaseStore
from app.services.oss_service import get_oss_service

router = APIRouter()


@router.post("/recognize-image", response_model=SuccessResponse[RecognitionResponseData])
async def recognize_image(
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
    file: UploadFile = File(...),
    source: str = Form(default="camera"),
) -> SuccessResponse[RecognitionResponseData]:
    content = await file.read()
    oss = get_oss_service()
    image_url = oss.upload_file(content, file.filename or "upload.jpg", file.content_type or "image/jpeg")
    claude = get_claude_service()
    recognition_result = claude.recognize_image(content)
    record = store.create_recognition(user.id, image_url=image_url, source=source, recognition_result=recognition_result)
    return SuccessResponse(data=RecognitionResponseData(**record))


@router.get("/recognitions", response_model=SuccessResponse[RecognitionListData])
def recognition_histories(
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
) -> SuccessResponse[RecognitionListData]:
    data = store.list_recognitions(user.id, page=page, limit=limit)
    records = [RecognitionListItem(**item) for item in data["records"]]
    return SuccessResponse(data=RecognitionListData(total=data["total"], records=records))


@router.post(
    "/recognitions/{recognition_id}/feedback",
    response_model=SuccessResponse[MessagePayload],
)
def recognition_feedback(
    recognition_id: str,
    payload: RecognitionFeedbackRequest,
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[MessagePayload]:
    store.add_recognition_feedback(
        user.id,
        recognition_id=recognition_id,
        feedback_type=payload.feedback_type,
        comment=payload.comment,
        correct_product_id=payload.correct_product_id,
    )
    return SuccessResponse(data=MessagePayload(message="反馈已记录"))


@router.post("/rag-chat", response_model=SuccessResponse[RagChatData])
def rag_chat(
    payload: RagChatRequest,
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[RagChatData]:
    data = store.chat(user_id=user.id, question=payload.question, session_id=payload.session_id)
    return SuccessResponse(data=RagChatData(**data))


@router.get("/conversations", response_model=SuccessResponse[ConversationListData])
def conversations(
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
) -> SuccessResponse[ConversationListData]:
    data = store.list_conversations(user.id, page=page, limit=limit)
    sessions = [ConversationListItem(**item) for item in data["sessions"]]
    return SuccessResponse(data=ConversationListData(total=data["total"], sessions=sessions))


@router.get("/conversations/{session_id}", response_model=SuccessResponse[ConversationDetailData])
def conversation_detail(
    session_id: str,
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[ConversationDetailData]:
    data = store.get_conversation_detail(user.id, session_id)
    return SuccessResponse(
        data=ConversationDetailData(
            session_id=data["session_id"],
            title=data["title"],
            updated_at=data["updated_at"],
            messages=[ConversationMessageData(**item) for item in data["messages"]],
        )
    )


@router.post(
    "/conversations/{session_id}/feedback",
    response_model=SuccessResponse[MessagePayload],
)
def conversation_feedback(
    session_id: str,
    payload: ConversationFeedbackRequest,
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[MessagePayload]:
    store.add_conversation_feedback(
        user.id,
        session_id=session_id,
        message_id=payload.message_id,
        rating=payload.rating,
        comment=payload.comment,
    )
    return SuccessResponse(data=MessagePayload(message="反馈已记录"))
