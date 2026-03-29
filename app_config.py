# app/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # 数据库
    DATABASE_URL: str = "sqlite:///./data/tool_store.db"
    REDIS_URL: str

    # Claude API
    CLAUDE_API_KEY: str = ""
    CLAUDE_BASE_URL: str = "https://code.newcli.com/claude/ultra"

    # 智谱AI Embedding
    ZHIPU_API_KEY: str = ""
    ZHIPU_BASE_URL: str = "https://open.bigmodel.cn/api/paas/v4"

    # Qdrant向量数据库
    QDRANT_URL: str = "http://localhost:6333"

    # 阿里云OSS对象存储
    OSS_REGION: str = "oss-cn-beijing"
    OSS_ACCESS_KEY_ID: str = ""
    OSS_ACCESS_KEY_SECRET: str = ""
    OSS_BUCKET_NAME: str = ""
    OSS_ENDPOINT: str = ""
    OSS_PATH_PREFIX: str = "uploads/"
    OSS_USE_SSL: bool = True
    OSS_USE_SIGN_URL: bool = True
    OSS_SIGN_URL_EXPIRES: int = 3600

    # 应用配置
    SECRET_KEY: str = "tool-store-dev-secret-key-change-me-2026"
    DEBUG: bool = False

    class Config:
        env_file = ".env"

settings = Settings()
