from __future__ import annotations

import base64
import json
import re

from anthropic import Anthropic

from app.config import settings


class ClaudeService:
    def __init__(self) -> None:
        self.client = (
            Anthropic(api_key=settings.claude_api_key, base_url=settings.claude_base_url)
            if settings.claude_api_key
            else None
        )
        self.last_error: str | None = None

    def recognize_image(self, image_content: bytes) -> dict:
        if self.client is not None:
            try:
                image_b64 = base64.b64encode(image_content).decode()
                message = self.client.messages.create(
                    model="claude-3-5-sonnet-20241022",
                    max_tokens=1024,
                    messages=[
                        {
                            "role": "user",
                            "content": [
                                {
                                    "type": "image",
                                    "source": {"type": "base64", "media_type": "image/jpeg", "data": image_b64},
                                },
                                {
                                    "type": "text",
                                    "text": "识别图片中的船用五金配件，返回JSON格式：{\"item_name\":\"配件名称\",\"category\":\"分类\",\"description\":\"描述\",\"features\":[\"特征1\"],\"usage\":\"用途\",\"safety_tips\":[\"提示1\"]}",
                                },
                            ],
                        }
                    ],
                )
                text = message.content[0].text
                try:
                    return json.loads(text)
                except json.JSONDecodeError:
                    return {
                        "item_name": "未知配件",
                        "category": "其他",
                        "description": text,
                        "features": [],
                        "usage": "",
                        "safety_tips": [],
                    }
            except Exception as exc:
                self.last_error = str(exc)

        preview = image_content[:120].decode("utf-8", errors="ignore")
        model_match = re.search(r"[A-Za-z]{1,4}\d{1,4}(?:[-/][A-Za-z0-9]+)*", preview)
        model_hint = model_match.group(0).upper() if model_match else ""
        description = "未配置视觉模型，已使用本地兜底识别结果。"
        if model_hint:
            description = f"{description} 检测到可能的型号线索：{model_hint}。"
        return {
            "item_name": model_hint or "待确认船用配件",
            "category": "待识别",
            "description": description,
            "features": ["建议补拍型号刻字", "建议补拍接口位置"],
            "usage": "用于离线联调和纠错反馈",
            "safety_tips": ["识别结果仅供初筛，安装前请核对型号"],
        }


_claude_service: ClaudeService | None = None


def get_claude_service() -> ClaudeService:
    global _claude_service
    if _claude_service is None:
        _claude_service = ClaudeService()
    return _claude_service
