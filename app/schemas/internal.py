from datetime import datetime

from pydantic import BaseModel, Field


class UploadDocumentData(BaseModel):
    message: str
    knowledge_ids: list[int]


class KnowledgeItemData(BaseModel):
    id: int
    title: str
    content: str
    product_ids: list[int]
    engine_models: list[str]
    source_ref: str | None = None
    source_type: str | None = None
    version: int
    status: str
    created_at: datetime
    updated_at: datetime


class KnowledgeListData(BaseModel):
    total: int
    items: list[KnowledgeItemData]


class KnowledgeVersionData(BaseModel):
    id: int
    knowledge_id: int
    version: int
    title: str
    content: str
    product_ids: list[int]
    engine_models: list[str]
    source_ref: str | None = None
    source_type: str | None = None
    status: str
    created_at: datetime


class KnowledgeVersionListData(BaseModel):
    total: int
    versions: list[KnowledgeVersionData]


class RollbackKnowledgeRequest(BaseModel):
    version: int


class UpdateKnowledgeRequest(BaseModel):
    title: str
    content: str
    product_ids: list[int] = Field(default_factory=list)
    engine_models: list[str] = Field(default_factory=list)


class BatchKnowledgeRequest(BaseModel):
    knowledge_ids: list[int] = Field(default_factory=list)


class ReindexRequest(BaseModel):
    knowledge_ids: list[int] = Field(default_factory=list)
    rebuild_mode: str = "incremental"


class ReindexData(BaseModel):
    job_id: int
    status: str
    rebuild_mode: str


class KnowledgeJobData(BaseModel):
    id: int
    job_type: str
    source_file: str | None = None
    status: str
    total_count: int
    success_count: int
    failed_count: int
    error_summary: str | None = None
    created_at: datetime
    updated_at: datetime


class KnowledgeJobListData(BaseModel):
    total: int
    jobs: list[KnowledgeJobData]


class CreateCategoryRequest(BaseModel):
    name: str
    parent_id: int | None = None
    icon_url: str | None = None


class CreateCategoryData(BaseModel):
    id: int
    name: str
    parent_id: int | None = None
    level: int
    icon_url: str | None = None


class CreateProductRequest(BaseModel):
    category_id: int
    name: str
    brand: str | None = None
    model_no: str | None = None
    description: str = ""
    price: float = 0
    images: list[str] = []
    specs: dict[str, str] = {}
    compatibility: list[str] = []
    usage_scenarios: str = ""
    safety_tips: list[str] = []
    keywords: list[str] = []


class CreateProductData(BaseModel):
    id: int
    name: str
    category_id: int


class UpdateProductRequest(BaseModel):
    category_id: int
    name: str
    brand: str | None = None
    model_no: str | None = None
    description: str = ""
    price: float = 0
    images: list[str] = []
    specs: dict[str, str] = {}
    compatibility: list[str] = []
    usage_scenarios: str = ""
    safety_tips: list[str] = []
    keywords: list[str] = []
