import os
from datetime import datetime
from typing import Optional
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.responses import StreamingResponse
from minio.error import S3Error

from .minio_client import get_minio_client, get_raw_videos_bucket
from .rss_generator import generate_rss_feed

app = FastAPI(title="RssFeedService", version="0.1.0")

# Get base URL from environment or use default
def get_base_url() -> str:
    base_url = os.getenv("BASE_URL", "http://rss-feed.local")
    return base_url.rstrip("/")

@app.get("/health")
async def health() -> dict:
    """Health check endpoint"""
    return {"status": "ok"}

@app.get("/rss")
async def get_rss_feed() -> Response:
    """
    Generate and return RSS feed of all videos in the MinIO bucket.
    """
    try:
        minio = get_minio_client()
        bucket = get_raw_videos_bucket()
        
        # List all objects in the bucket
        objects = []
        try:
            for obj in minio.list_objects(bucket, recursive=True):
                # Get object metadata
                stat = minio.stat_object(bucket, obj.object_name)
                meta = {k.lower(): v for k, v in (stat.metadata or {}).items()}
                duration = int(meta.get("x-amz-meta-duration") or meta.get("duration") or 0)
                objects.append({
                    "name": obj.object_name,
                    "size": stat.size,
                    "last_modified": stat.last_modified,
                    "content_type": stat.content_type or "video/mp4",
                    "duration": duration,
                })
        except S3Error as e:
            raise HTTPException(status_code=500, detail=f"Failed to list objects: {str(e)}") from e
        
        # Sort by last modified (newest first)
        objects.sort(key=lambda x: x.get("last_modified", datetime.min), reverse=True)
        
        # Generate RSS feed
        base_url = get_base_url()
        feed_xml = generate_rss_feed(
            videos=objects,
            feed_title="YTR Video Feed",
            feed_description="RSS feed of all videos in the YTR platform",
            feed_link=f"{base_url}/rss",
            base_url=base_url,
        )
        
        return Response(
            content=feed_xml,
            media_type="application/rss+xml",
            headers={"Content-Disposition": 'inline; filename="feed.xml"'},
        )
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Failed to generate RSS feed: {str(e)}") from e

@app.get("/video/{object_name:path}")
async def stream_video(object_name: str, request: Request) -> StreamingResponse:
    """
    Stream video from MinIO. Supports HTTP range requests for video seeking.
    """
    try:
        minio = get_minio_client()
        bucket = get_raw_videos_bucket()
        
        # Get object metadata
        try:
            stat = minio.stat_object(bucket, object_name)
        except S3Error as e:
            if e.code == "NoSuchKey":
                raise HTTPException(status_code=404, detail=f"Video not found: {object_name}") from e
            raise HTTPException(status_code=500, detail=f"Failed to access video: {str(e)}") from e
        
        # Handle range requests for video seeking
        range_header = request.headers.get("range")
        start = 0
        end = stat.size - 1
        
        if range_header:
            # Parse range header (e.g., "bytes=0-1023")
            range_match = range_header.replace("bytes=", "").split("-")
            start = int(range_match[0]) if range_match[0] else 0
            end = int(range_match[1]) if range_match[1] and range_match[1] else stat.size - 1
        
        # Get object data
        try:
            data = minio.get_object(bucket, object_name, offset=start, length=end - start + 1)
            
            # Determine content type
            content_type = stat.content_type or "video/mp4"
            
            # Set response headers
            headers = {
                "Content-Type": content_type,
                "Accept-Ranges": "bytes",
                "Content-Length": str(end - start + 1),
            }
            
            if range_header:
                headers["Content-Range"] = f"bytes {start}-{end}/{stat.size}"
                status_code = 206  # Partial Content
            else:
                status_code = 200
            
            # Generator function to stream data in chunks
            def generate():
                try:
                    while True:
                        chunk = data.read(8192)
                        if not chunk:
                            break
                        yield chunk
                finally:
                    data.close()
            
            return StreamingResponse(
                generate(),
                status_code=status_code,
                headers=headers,
                media_type=content_type,
            )
        except S3Error as e:
            raise HTTPException(status_code=500, detail=f"Failed to stream video: {str(e)}") from e
    except HTTPException:
        raise
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}") from e

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
