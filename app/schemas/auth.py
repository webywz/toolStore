from typing import Annotated

from pydantic import AliasChoices, BaseModel, Field, StringConstraints

AccountStr = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=64),
]
PasswordStr = Annotated[
    str,
    StringConstraints(min_length=6, max_length=128),
]
NicknameStr = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=32),
]


class RegisterRequest(BaseModel):
    account: AccountStr = Field(validation_alias=AliasChoices("account", "phone"))
    password: PasswordStr
    nickname: NicknameStr


class LoginRequest(BaseModel):
    account: AccountStr = Field(validation_alias=AliasChoices("account", "phone"))
    password: PasswordStr


class ResetPasswordRequest(BaseModel):
    account: AccountStr = Field(validation_alias=AliasChoices("account", "phone"))
    new_password: PasswordStr


class ChangePasswordRequest(BaseModel):
    old_password: PasswordStr
    new_password: PasswordStr


class AuthData(BaseModel):
    user_id: int
    token: str
    nickname: str


class CurrentUserData(BaseModel):
    id: int
    account: str
    nickname: str
    avatar_url: str | None = None
    is_admin: bool = False
