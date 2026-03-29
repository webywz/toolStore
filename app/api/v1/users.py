from typing import Annotated

from fastapi import APIRouter, Depends, File, UploadFile

from app.core.exceptions import BusinessError
from app.core.deps import get_current_user, get_store, is_admin_user
from app.models.entities import User
from app.schemas.auth import CurrentUserData
from app.schemas.common import SuccessResponse
from app.schemas.users import UpdateCurrentUserRequest
from app.services.db_store import DatabaseStore
from app.services.oss_service import get_oss_service

router = APIRouter()


@router.get("/me", response_model=SuccessResponse[CurrentUserData])
def current_user(
    user: Annotated[User, Depends(get_current_user)],
) -> SuccessResponse[CurrentUserData]:
    return SuccessResponse(
        data=CurrentUserData(
            id=user.id,
            account=user.phone,
            nickname=user.nickname,
            avatar_url=user.avatar_url,
            is_admin=is_admin_user(user),
        )
    )


@router.put("/me", response_model=SuccessResponse[CurrentUserData])
def update_current_user(
    payload: UpdateCurrentUserRequest,
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[CurrentUserData]:
    data = store.update_user_profile(
        user.id,
        nickname=payload.nickname,
        avatar_url=payload.avatar_url,
    )
    return SuccessResponse(
        data=CurrentUserData(
            id=data["id"],
            account=data["account"],
            nickname=data["nickname"],
            avatar_url=data["avatar_url"],
            is_admin=is_admin_user(user),
        )
    )


@router.post("/me/avatar", response_model=SuccessResponse[CurrentUserData])
async def upload_current_user_avatar(
    user: Annotated[User, Depends(get_current_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
    file: UploadFile = File(...),
) -> SuccessResponse[CurrentUserData]:
    content = await file.read()
    if not content:
        raise BusinessError(status_code=400, code=400, message="头像文件不能为空")
    oss = get_oss_service()
    avatar_url = oss.upload_file(
        content,
        file.filename or "avatar.jpg",
        file.content_type or "image/jpeg",
    )
    data = store.update_user_avatar(user.id, avatar_url)
    return SuccessResponse(
        data=CurrentUserData(
            id=data["id"],
            account=data["account"],
            nickname=data["nickname"],
            avatar_url=data["avatar_url"],
            is_admin=is_admin_user(user),
        )
    )
