# How to Check MinIO for Downloaded Videos

## Quick Method: MinIO Web Console (Easiest)

### Step 1: Port-Forward MinIO Console

```bash
kubectl port-forward -n ytr-dev svc/dev-platform-minio 9091:9090
```

### Step 2: Open in Browser

Open: **http://localhost:9091**

**Login:**
- Username: `minioadmin`
- Password: `minioadmin`

### Step 3: Check Bucket

1. Click **"Buckets"** in the left sidebar
2. Click on **`raw-videos-dev`** bucket
3. You'll see all downloaded video files listed

---

## Method 2: Using Helper Script

Run the helper script:

```bash
bash scripts/access-minio.sh
```

This will:
- Start port-forward automatically
- Show you the access URL and credentials
- Tell you which bucket to check

---

## Method 3: Command Line (Quick Check)

Check bucket contents from command line:

```bash
# Port-forward MinIO API (not console)
kubectl port-forward -n ytr-dev svc/dev-platform-minio 9000:9000 &

# Use MinIO client (if installed locally)
mc alias set local http://localhost:9000 minioadmin minioadmin
mc ls local/raw-videos-dev/
```

Or use the check script:

```bash
bash scripts/check-minio-bucket.sh raw-videos-dev
```

---

## Method 4: From Inside Kubernetes

Run a pod with MinIO client:

```bash
kubectl run minio-client --image=minio/mc:latest --restart=Never -n ytr-dev -it --rm -- \
  /bin/sh -c "
    mc alias set minio http://dev-platform-minio:9000 minioadmin minioadmin && \
    mc ls minio/raw-videos-dev/
  "
```

---

## What You'll See

### In MinIO Console:
- **File list** with:
  - Video filename (e.g., `dQw4w9WgXcQ.mp4`)
  - File size
  - Last modified date
  - Download/Preview options

### Expected Files:
After downloading a video, you should see:
```
raw-videos-dev/
  └── <video-id>.mp4  (or .webm, .mkv, etc.)
```

Example:
```
raw-videos-dev/
  └── dQw4w9WgXcQ.mp4  (15.2 MB)
```

---

## Quick Verification Commands

### Check if bucket exists:
```bash
kubectl run minio-check --image=minio/mc:latest --restart=Never -n ytr-dev -it --rm -- \
  /bin/sh -c "mc alias set minio http://dev-platform-minio:9000 minioadmin minioadmin && mc ls minio/"
```

### List bucket contents:
```bash
kubectl run minio-list --image=minio/mc:latest --restart=Never -n ytr-dev -it --rm -- \
  /bin/sh -c "mc alias set minio http://dev-platform-minio:9000 minioadmin minioadmin && mc ls minio/raw-videos-dev/"
```

### Get file count:
```bash
kubectl run minio-count --image=minio/mc:latest --restart=Never -n ytr-dev -it --rm -- \
  /bin/sh -c "mc alias set minio http://dev-platform-minio:9000 minioadmin minioadmin && mc ls minio/raw-videos-dev/ | wc -l"
```

---

## Troubleshooting

### Port already in use?
```bash
# Kill existing port-forward
lsof -ti:9091 | xargs kill -9

# Or use different port
kubectl port-forward -n ytr-dev svc/dev-platform-minio 9092:9090
```

### Can't see bucket?
1. Check bucket name matches: `raw-videos-dev`
2. Verify bucket was created: Check bucket initialization job
3. Check service name: Should be `dev-platform-minio`

### No files in bucket?
1. Check if download completed successfully
2. Check file-downloader logs: `kubectl logs -n ytr-dev -l app=file-downloader`
3. Verify bucket name in deployment matches

---

## Summary

**Easiest way:** Use the web console
```bash
kubectl port-forward -n ytr-dev svc/dev-platform-minio 9091:9090
# Then open http://localhost:9091 (minioadmin/minioadmin)
```

**Quick check:** Use the script
```bash
bash scripts/access-minio.sh
```
