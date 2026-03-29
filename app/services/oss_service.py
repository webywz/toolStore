from __future__ import annotations

from pathlib import Path
import uuid

import oss2

from app.config import settings


class OSSService:
    def __init__(self) -> None:
        self.bucket: oss2.Bucket | None = None
        self.local_root = Path.cwd() / "data" / "uploads"
        self.local_root.mkdir(parents=True, exist_ok=True)
        if settings.oss_access_key_id and settings.oss_access_key_secret and settings.oss_bucket_name and settings.oss_endpoint:
            auth = oss2.Auth(settings.oss_access_key_id, settings.oss_access_key_secret)
            self.bucket = oss2.Bucket(auth, settings.oss_endpoint, settings.oss_bucket_name)

    def upload_file(self, file_content: bytes, filename: str, content_type: str = "image/jpeg") -> str:
        ext = filename.rsplit(".", 1)[-1] if "." in filename else "jpg"
        key = f"{settings.oss_path_prefix}{uuid.uuid4().hex}.{ext}"
        if self.bucket is not None:
            try:
                self.bucket.put_object(key, file_content, headers={"Content-Type": content_type})

                if settings.oss_use_sign_url:
                    return self.bucket.sign_url("GET", key, settings.oss_sign_url_expires)

                protocol = "https" if settings.oss_use_ssl else "http"
                return f"{protocol}://{settings.oss_bucket_name}.{settings.oss_region}.aliyuncs.com/{key}"
            except Exception:
                pass

        local_path = self.local_root / key
        local_path.parent.mkdir(parents=True, exist_ok=True)
        local_path.write_bytes(file_content)
        return f"/local-uploads/{key}"


_oss_service: OSSService | None = None


def get_oss_service() -> OSSService:
    global _oss_service
    if _oss_service is None:
        _oss_service = OSSService()
    return _oss_service
