from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.database import SessionLocal
from app.core.exceptions import BusinessError
from app.config import settings
from app.models.entities import User
from app.services.db_store import DatabaseStore

bearer_scheme = HTTPBearer(auto_error=False)


def get_db_session() -> Session:
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


def get_db() -> Session:
    yield from get_db_session()


def get_store(session: Annotated[Session, Depends(get_db_session)]) -> DatabaseStore:
    return DatabaseStore(session)


def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    session: Annotated[Session, Depends(get_db_session)],
) -> User:
    if credentials is None:
        raise BusinessError(status_code=401, code=401, message="未授权")
    user_id = decode_access_token(credentials.credentials)
    user = session.get(User, user_id)
    if user is None:
        raise BusinessError(status_code=401, code=401, message="未授权")
    return user


def get_optional_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    session: Annotated[Session, Depends(get_db_session)],
) -> User | None:
    if credentials is None:
        return None
    try:
        user_id = decode_access_token(credentials.credentials)
    except BusinessError:
        return None
    return session.get(User, user_id)


def is_admin_user(user: User) -> bool:
    admin_phones = {item.strip() for item in settings.admin_phones.split(",") if item.strip()}
    return user.phone in admin_phones


def get_admin_user(
    user: Annotated[User, Depends(get_current_user)],
) -> User:
    if not is_admin_user(user):
        raise BusinessError(status_code=403, code=403, message="无管理员权限")
    return user
