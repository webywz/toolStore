from typing import Annotated

from pydantic import BaseModel, StringConstraints

NicknameStr = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=32),
]
AvatarUrlStr = Annotated[
    str,
    StringConstraints(strip_whitespace=True, max_length=255),
]


class UpdateCurrentUserRequest(BaseModel):
    nickname: NicknameStr
    avatar_url: AvatarUrlStr | None = None
