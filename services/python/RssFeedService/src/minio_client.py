import os
from minio import Minio

_minio_client: Minio | None = None

def get_minio_client() -> Minio:
    global _minio_client
    if _minio_client is None:
        endpoint = os.getenv("MINIO_ENDPOINT", "minio:9000")
        access_key = os.getenv("MINIO_ACCESS_KEY") or os.getenv("MINIO_ROOT_USER")
        secret_key = os.getenv("MINIO_SECRET_KEY") or os.getenv("MINIO_ROOT_PASSWORD")
        secure = os.getenv("MINIO_SECURE", "false").lower() == "true"
        _minio_client = Minio(
            endpoint=endpoint,
            access_key=access_key,
            secret_key=secret_key,
            secure=secure,
        )
    return _minio_client

def get_raw_videos_bucket() -> str:
    return os.getenv("RAW_VIDEOS_BUCKET", "raw-videos")
