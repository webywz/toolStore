from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.deps import get_current_user, get_store
from app.models.entities import User
from app.schemas.auth import (
    AuthData,
    ChangePasswordRequest,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
)
from app.schemas.common import MessagePayload, SuccessResponse
from app.services.db_store import DatabaseStore

router = APIRouter()


@router.post("/register", response_model=SuccessResponse[AuthData])
def register(
    payload: RegisterRequest,
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[AuthData]:
    data = store.register_user(payload.account, payload.password, payload.nickname)
    return SuccessResponse(data=AuthData(**data))


@router.post("/login", response_model=SuccessResponse[AuthData])
def login(
    payload: LoginRequest,
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[AuthData]:
    data = store.login_user(payload.account, payload.password)
    return SuccessResponse(data=AuthData(**data))


@router.post("/reset-password", response_model=SuccessResponse[MessagePayload])
def reset_password(
    payload: ResetPasswordRequest,
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[MessagePayload]:
    store.reset_password(payload.account, payload.new_password)
    return SuccessResponse(data=MessagePayload(message="密码已重置，请重新登录"))


@router.post("/change-password", response_model=SuccessResponse[MessagePayload])
def change_password(
    payload: ChangePasswordRequest,
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[MessagePayload]:
    store.change_password(user.id, payload.old_password, payload.new_password)
    return SuccessResponse(data=MessagePayload(message="密码修改成功"))
