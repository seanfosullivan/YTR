import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, HttpUrl

from .core import download_and_upload

app = FastAPI(title="FileDownloader", version="0.1.0")


class DownloadRequest(BaseModel):
    url: str


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.post("/download")
async def download_video(request: DownloadRequest) -> dict:
    """Download a YouTube video and upload it to MinIO"""
    try:
        result = await download_and_upload(request.url)
        return result
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=str(exc)) from exc


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
