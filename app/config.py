from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "sqlite:///./data/tool_store.db"
    redis_url: str = "redis://localhost:6379"
    claude_api_key: str = ""
    claude_base_url: str = "https://code.newcli.com/claude/ultra"
    zhipu_api_key: str = ""
    zhipu_base_url: str = "https://open.bigmodel.cn/api/paas/v4"
    qdrant_url: str = "http://localhost:6333"
    oss_region: str = "oss-cn-beijing"
    oss_access_key_id: str = ""
    oss_access_key_secret: str = ""
    oss_bucket_name: str = ""
    oss_endpoint: str = ""
    oss_path_prefix: str = "uploads/"
    oss_use_ssl: bool = True
    oss_use_sign_url: bool = True
    oss_sign_url_expires: int = 3600
    secret_key: str = "tool-store-dev-secret-key-change-me-2026"
    admin_phones: str = "13800138000"
    debug: bool = False

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
