import os
import re
import tempfile
from pathlib import Path

from yt_dlp import YoutubeDL

from .minio_client import get_minio_client, get_raw_videos_bucket


async def download_and_upload(url: str) -> dict:
    if "youtube.com" not in url and "youtu.be" not in url:
        raise ValueError("Only YouTube URLs are supported")

    tmp_dir = tempfile.mkdtemp(prefix="ytdl-")
    output_template = str(Path(tmp_dir) / "%(id)s.%(ext)s")

    ydl_opts = {
        "outtmpl": output_template,
        "format": os.getenv("YTDL_FORMAT", "best[height<=720]/best"),
        "noplaylist": True,  # Don't download playlists, just the single video
        "quiet": True,  # Suppress output
        "no_warnings": False,  # Show warnings for debugging
        "retries": 5,  # Retry failed downloads
        "fragment_retries": 5,  # Retry failed fragments
        "socket_timeout": 30,  # Timeout for socket operations
        "extractor_args": {
            "youtube": {
                "player_client": ["android", "web"],  # Try different clients
                "player_skip": ["webpage", "configs"],  # Skip problematic parts
            }
        },
        # Better user agent to avoid 403 errors
        "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "referer": "https://www.youtube.com/",
        "http_headers": {
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-us,en;q=0.5",
            "Sec-Fetch-Mode": "navigate",
        },
    }

    with YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        video_id = info.get("id")
        ext = info.get("ext", "mp4")
        title = info.get("title") or video_id
        safe_title = re.sub(r'[^\w\s\-]', '', title).strip()
        safe_title = re.sub(r'[\s]+', '_', safe_title)[:100]
        filename = f"{safe_title}.{ext}"
        # yt-dlp still wrote the file using video_id, find it
        file_path = Path(tmp_dir) / f"{video_id}.{ext}"

        if not file_path.exists():
            msg = "Downloaded file not found on disk"
            raise RuntimeError(msg)

        minio = get_minio_client()
        bucket = get_raw_videos_bucket()

        duration = int(info.get("duration") or 0)
        metadata = {
            "x-amz-meta-title": info.get("title") or video_id,
            "x-amz-meta-duration": str(duration),
        }

        object_name = filename  # stored in MinIO with the title-based name
        minio.fput_object(
            bucket_name=bucket,
            object_name=object_name,
            file_path=str(file_path),
            content_type="video/mp4",
            metadata=metadata,
        )

    return {
        "message": "Download complete",
        "url": url,
        "video_id": video_id,
        "bucket": bucket,
        "object_name": object_name,
    }
