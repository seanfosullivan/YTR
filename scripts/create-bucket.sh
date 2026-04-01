#!/bin/bash
# Create raw-videos-dev bucket in MinIO

set -euo pipefail

NAMESPACE="${NAMESPACE:-ytr-dev}"

echo "Creating raw-videos-dev bucket in MinIO..."

kubectl run minio-bucket-creator \
  --image=minio/mc:latest \
  --restart=Never \
  -n "$NAMESPACE" \
  --rm -i -- \
  sh -c "
    echo 'Setting up MinIO alias...'
    mc alias set minio http://dev-platform-minio:9000 minioadmin minioadmin
    echo 'Creating bucket raw-videos-dev...'
    mc mb minio/raw-videos-dev --ignore-existing || true
    echo 'Listing buckets...'
    mc ls minio/
    echo 'Bucket created successfully!'
  "

echo ""
echo "✅ Bucket creation complete"
