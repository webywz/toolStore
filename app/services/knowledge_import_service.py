from __future__ import annotations

from dataclasses import dataclass
import csv
import hashlib
import io
import json
from pathlib import Path
import re

from app.core.exceptions import BusinessError

_MODEL_PATTERN = re.compile(r"\b[A-Z]{1,4}\d{1,4}(?:[-/][A-Z0-9]+)*\b")


@dataclass(frozen=True)
class ParsedKnowledgeChunk:
    title: str
    content: str
    engine_models: list[str]
    content_hash: str


def parse_document_chunks(filename: str, file_content: bytes) -> list[ParsedKnowledgeChunk]:
    text = _extract_text(filename, file_content)
    normalized = _normalize_text(text)
    if not normalized:
        raise BusinessError(status_code=422, code=40002, message="文档内容为空，无法导入知识库")

    raw_chunks = _split_chunks(normalized)
    stem = Path(filename).stem or "知识文档"
    return [
        ParsedKnowledgeChunk(
            title=_build_chunk_title(stem, chunk, index),
            content=chunk,
            engine_models=_extract_engine_models(chunk),
            content_hash=hashlib.sha256(f"{filename}:{chunk}".encode("utf-8")).hexdigest(),
        )
        for index, chunk in enumerate(raw_chunks, start=1)
    ]


def _extract_text(filename: str, file_content: bytes) -> str:
    suffix = Path(filename).suffix.lower()
    if suffix in {".txt", ".md", ".markdown", ".rst", ".log"}:
        return _decode_text(file_content)
    if suffix == ".csv":
        return _csv_to_text(file_content)
    if suffix == ".json":
        return _json_to_text(file_content)
    if suffix == ".pdf":
        return _pdf_to_text(file_content)

    decoded = _decode_text(file_content, strict=False)
    if decoded.strip():
        return decoded
    raise BusinessError(
        status_code=415,
        code=40003,
        message="当前仅支持导入 txt、md、csv、json 和可解析的 pdf 文档",
    )


def _decode_text(file_content: bytes, *, strict: bool = True) -> str:
    encodings = ("utf-8", "utf-8-sig", "gb18030", "latin-1")
    for encoding in encodings:
        try:
            return file_content.decode(encoding)
        except UnicodeDecodeError:
            continue
    if strict:
        raise BusinessError(status_code=415, code=40004, message="文档编码无法识别，请转换为 UTF-8 后重试")
    return file_content.decode("utf-8", errors="ignore")


def _csv_to_text(file_content: bytes) -> str:
    decoded = _decode_text(file_content)
    reader = csv.reader(io.StringIO(decoded))
    rows = [" | ".join(cell.strip() for cell in row if cell.strip()) for row in reader]
    return "\n".join(row for row in rows if row)


def _json_to_text(file_content: bytes) -> str:
    try:
        payload = json.loads(_decode_text(file_content))
    except json.JSONDecodeError as exc:
        raise BusinessError(status_code=422, code=40005, message="JSON 文档格式错误，无法导入") from exc
    lines = _flatten_json(payload)
    return "\n".join(line for line in lines if line.strip())


def _flatten_json(payload: object, prefix: str = "") -> list[str]:
    if isinstance(payload, dict):
        lines: list[str] = []
        for key, value in payload.items():
            next_prefix = f"{prefix}.{key}" if prefix else str(key)
            lines.extend(_flatten_json(value, next_prefix))
        return lines
    if isinstance(payload, list):
        lines: list[str] = []
        for index, value in enumerate(payload, start=1):
            next_prefix = f"{prefix}[{index}]" if prefix else f"[{index}]"
            lines.extend(_flatten_json(value, next_prefix))
        return lines
    if payload is None:
        return []
    text = str(payload).strip()
    if not text:
        return []
    return [f"{prefix}: {text}" if prefix else text]


def _pdf_to_text(file_content: bytes) -> str:
    try:
        from pypdf import PdfReader  # type: ignore
    except ImportError as exc:
        raise BusinessError(
            status_code=415,
            code=40006,
            message="当前环境未安装 PDF 解析依赖，请先导入 txt、md、csv 或 json 文档",
        ) from exc

    reader = PdfReader(io.BytesIO(file_content))
    pages = [(page.extract_text() or "").strip() for page in reader.pages]
    text = "\n\n".join(page for page in pages if page)
    if not text.strip():
        raise BusinessError(status_code=422, code=40007, message="PDF 未解析出有效文本，请检查文件内容")
    return text


def _normalize_text(text: str) -> str:
    cleaned = text.replace("\r\n", "\n").replace("\r", "\n").replace("\x00", "")
    lines = [re.sub(r"[ \t]+", " ", line).strip() for line in cleaned.split("\n")]
    paragraphs: list[str] = []
    current: list[str] = []
    for line in lines:
        if not line:
            if current:
                paragraphs.append(" ".join(current).strip())
                current = []
            continue
        current.append(line)
    if current:
        paragraphs.append(" ".join(current).strip())
    return "\n\n".join(paragraph for paragraph in paragraphs if paragraph)


def _split_chunks(text: str, *, max_chars: int = 420) -> list[str]:
    paragraphs = [item.strip() for item in text.split("\n\n") if item.strip()]
    if not paragraphs:
        return []

    chunks: list[str] = []
    current: list[str] = []
    current_length = 0

    for paragraph in paragraphs:
        if len(paragraph) > max_chars:
            sentences = [item.strip() for item in re.split(r"(?<=[。！？.!?；;])\s*", paragraph) if item.strip()]
        else:
            sentences = [paragraph]
        for sentence in sentences:
            projected = current_length + len(sentence) + (1 if current else 0)
            if current and projected > max_chars:
                chunks.append("\n".join(current))
                current = [sentence]
                current_length = len(sentence)
            else:
                current.append(sentence)
                current_length = projected

    if current:
        chunks.append("\n".join(current))

    return [chunk.strip() for chunk in chunks if chunk.strip()]


def _build_chunk_title(stem: str, chunk: str, index: int) -> str:
    first_line = chunk.splitlines()[0].strip()
    if first_line and len(first_line) <= 32:
        return f"{stem} - {first_line}"
    return f"{stem} - 片段 {index}"


def _extract_engine_models(content: str) -> list[str]:
    seen: dict[str, None] = {}
    for match in _MODEL_PATTERN.findall(content.upper()):
        seen.setdefault(match, None)
    return list(seen.keys())[:10]
