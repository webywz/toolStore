from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.v1 import api_router
from app.bootstrap import seed_database
from app.core.exceptions import register_exception_handlers
from app.core.logging import setup_logging, logger
from app.core.rate_limit import rate_limit_middleware
from app.database import init_database


def create_app() -> FastAPI:
    setup_logging()
    logger.info("Starting application...")

    init_database()
    seed_database()

    app = FastAPI(
        title="船用五金 AI 识别与查询工具 API",
        version="0.1.0",
        docs_url="/docs",
        redoc_url="/redoc",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.middleware("http")(rate_limit_middleware)

    register_exception_handlers(app)

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    app.include_router(api_router, prefix="/api/v1")

    uploads_dir = Path.cwd() / "data" / "uploads"
    uploads_dir.mkdir(parents=True, exist_ok=True)
    app.mount("/local-uploads", StaticFiles(directory=str(uploads_dir)), name="uploads")

    logger.info("Application started successfully")
    return app


app = create_app()
