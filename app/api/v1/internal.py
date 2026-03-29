from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile

from app.core.deps import get_admin_user, get_store
from app.models.entities import User
from app.schemas.common import MessagePayload, SuccessResponse
from app.schemas.internal import (
    BatchKnowledgeRequest,
    CreateCategoryData,
    CreateCategoryRequest,
    CreateProductData,
    CreateProductRequest,
    KnowledgeItemData,
    KnowledgeJobData,
    KnowledgeJobListData,
    KnowledgeListData,
    KnowledgeVersionData,
    KnowledgeVersionListData,
    ReindexData,
    ReindexRequest,
    RollbackKnowledgeRequest,
    UpdateProductRequest,
    UpdateKnowledgeRequest,
    UploadDocumentData,
)
from app.services.db_store import DatabaseStore

router = APIRouter()


@router.post("/knowledge/upload-document", response_model=SuccessResponse[UploadDocumentData])
async def upload_document(
    _: Annotated[User, Depends(get_admin_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
    file: UploadFile = File(...),
    product_ids: str = Form(default=""),
) -> SuccessResponse[UploadDocumentData]:
    product_id_list = [int(item) for item in product_ids.split(",") if item.strip().isdigit()]
    content = await file.read()
    data = store.upload_document(
        filename=file.filename or "document.pdf",
        file_content=content,
        product_ids=product_id_list,
    )
    return SuccessResponse(
        data=UploadDocumentData(
            message=data["message"],
            knowledge_ids=data["knowledge_ids"],
        )
    )


@router.get("/knowledge/items", response_model=SuccessResponse[KnowledgeListData])
def list_knowledge_items(
    _: Annotated[User, Depends(get_admin_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    keyword: str | None = Query(default=None),
) -> SuccessResponse[KnowledgeListData]:
    data = store.list_knowledge_items(page=page, limit=limit, keyword=keyword)
    items = [KnowledgeItemData(**item) for item in data["items"]]
    return SuccessResponse(data=KnowledgeListData(total=data["total"], items=items))


@router.put("/knowledge/items/{knowledge_id}", response_model=SuccessResponse[KnowledgeItemData])
def update_knowledge_item(
    knowledge_id: int,
    _: Annotated[User, Depends(get_admin_user)],
    payload: UpdateKnowledgeRequest,
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[KnowledgeItemData]:
    data = store.update_knowledge_item(knowledge_id, payload.model_dump())
    return SuccessResponse(data=KnowledgeItemData(**data))


@router.get("/knowledge/items/{knowledge_id}/versions", response_model=SuccessResponse[KnowledgeVersionListData])
def list_knowledge_versions(
    knowledge_id: int,
    _: Annotated[User, Depends(get_admin_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[KnowledgeVersionListData]:
    data = store.list_knowledge_versions(knowledge_id)
    versions = [KnowledgeVersionData(**item) for item in data["versions"]]
    return SuccessResponse(data=KnowledgeVersionListData(total=data["total"], versions=versions))


@router.post("/knowledge/items/{knowledge_id}/rollback", response_model=SuccessResponse[KnowledgeItemData])
def rollback_knowledge_item(
    knowledge_id: int,
    payload: RollbackKnowledgeRequest,
    _: Annotated[User, Depends(get_admin_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[KnowledgeItemData]:
    data = store.rollback_knowledge_item(knowledge_id, payload.version)
    return SuccessResponse(data=KnowledgeItemData(**data))


@router.delete("/knowledge/items/{knowledge_id}", response_model=SuccessResponse[MessagePayload])
def delete_knowledge_item(
    knowledge_id: int,
    _: Annotated[User, Depends(get_admin_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[MessagePayload]:
    store.delete_knowledge_item(knowledge_id)
    return SuccessResponse(data=MessagePayload(message="知识片段已删除"))


@router.post("/knowledge/items/batch-delete", response_model=SuccessResponse[MessagePayload])
def batch_delete_knowledge_items(
    _: Annotated[User, Depends(get_admin_user)],
    payload: BatchKnowledgeRequest,
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[MessagePayload]:
    deleted = store.delete_knowledge_items(payload.knowledge_ids)
    return SuccessResponse(data=MessagePayload(message=f"已删除 {deleted} 条知识片段"))


@router.post("/knowledge/reindex", response_model=SuccessResponse[ReindexData])
def reindex(
    _: Annotated[User, Depends(get_admin_user)],
    payload: ReindexRequest,
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[ReindexData]:
    data = store.reindex(
        knowledge_ids=payload.knowledge_ids,
        rebuild_mode=payload.rebuild_mode,
    )
    return SuccessResponse(data=ReindexData(**data))


@router.get("/knowledge/jobs", response_model=SuccessResponse[KnowledgeJobListData])
def list_jobs(
    _: Annotated[User, Depends(get_admin_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
) -> SuccessResponse[KnowledgeJobListData]:
    data = store.list_jobs(page=page, limit=limit)
    jobs = [KnowledgeJobData(**item) for item in data["jobs"]]
    return SuccessResponse(data=KnowledgeJobListData(total=data["total"], jobs=jobs))


@router.get("/knowledge/jobs/{job_id}", response_model=SuccessResponse[KnowledgeJobData])
def job_detail(
    job_id: int,
    _: Annotated[User, Depends(get_admin_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[KnowledgeJobData]:
    return SuccessResponse(data=KnowledgeJobData(**store.get_job(job_id)))


@router.post("/categories", response_model=SuccessResponse[CreateCategoryData])
def create_category(
    _: Annotated[User, Depends(get_admin_user)],
    payload: CreateCategoryRequest,
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[CreateCategoryData]:
    data = store.create_category(payload.name, payload.parent_id, payload.icon_url)
    return SuccessResponse(data=CreateCategoryData(**data))


@router.post("/products", response_model=SuccessResponse[CreateProductData])
def create_product(
    _: Annotated[User, Depends(get_admin_user)],
    payload: CreateProductRequest,
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[CreateProductData]:
    data = store.create_product(payload.model_dump())
    return SuccessResponse(data=CreateProductData(**data))


@router.put("/products/{product_id}", response_model=SuccessResponse[CreateProductData])
def update_product(
    product_id: int,
    _: Annotated[User, Depends(get_admin_user)],
    payload: UpdateProductRequest,
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[CreateProductData]:
    data = store.update_product(product_id, payload.model_dump())
    return SuccessResponse(data=CreateProductData(**data))


@router.delete("/products/{product_id}", response_model=SuccessResponse[MessagePayload])
def delete_product(
    product_id: int,
    _: Annotated[User, Depends(get_admin_user)],
    store: Annotated[DatabaseStore, Depends(get_store)],
) -> SuccessResponse[MessagePayload]:
    store.delete_product(product_id)
    return SuccessResponse(data=MessagePayload(message="商品已删除"))
