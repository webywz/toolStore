from __future__ import annotations

from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import settings


class Base(DeclarativeBase):
    pass


def _is_sqlite(url: str) -> bool:
    return url.startswith("sqlite")


def _ensure_sqlite_directory(url: str) -> None:
    if not _is_sqlite(url):
        return
    if url.startswith("sqlite:///./"):
        relative_path = url.removeprefix("sqlite:///./")
        db_path = Path.cwd() / relative_path
    elif url.startswith("sqlite:///"):
        db_path = Path(url.removeprefix("sqlite:///"))
    else:
        return
    if db_path.parent != Path():
        db_path.parent.mkdir(parents=True, exist_ok=True)


_ensure_sqlite_directory(settings.database_url)

connect_args = {"check_same_thread": False} if _is_sqlite(settings.database_url) else {}
engine = create_engine(
    settings.database_url,
    future=True,
    pool_pre_ping=True,
    connect_args=connect_args,
)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, expire_on_commit=False)


def init_database() -> None:
    from app.models import entities  # noqa: F401

    Base.metadata.create_all(bind=engine)
