#!/bin/bash
# Quick script to check MinIO bucket contents using kubectl

set -euo pipefail

NAMESPACE="${NAMESPACE:-ytr-dev}"
BUCKET="${1:-raw-videos-dev}"

echo "Checking MinIO bucket: $BUCKET"
echo ""

# Get MinIO service name
MINIO_SERVICE=$(kubectl get svc -n "$NAMESPACE" | grep minio | awk '{print $1}' | head -1)

if [[ -z "$MINIO_SERVICE" ]]; then
    echo "❌ Error: MinIO service not found"
    exit 1
fi

echo "Using MinIO service: $MINIO_SERVICE"
echo ""

# Create a job to check bucket contents
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: minio-check-$(date +%s)
  namespace: $NAMESPACE
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: mc
          image: minio/mc:latest
          command:
            - /bin/sh
            - -c
            - |
              echo "Connecting to MinIO..."
              mc alias set minio http://${MINIO_SERVICE}:9000 minioadmin minioadmin
              echo ""
              echo "Bucket: $BUCKET"
              echo "Contents:"
              echo "----------------------------------------"
              mc ls minio/$BUCKET/ || echo "Bucket is empty or does not exist"
              echo "----------------------------------------"
              echo ""
              echo "Bucket size:"
              mc du minio/$BUCKET/ 2>/dev/null || echo "Unable to calculate size"
EOF

JOB_NAME=$(kubectl get jobs -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp | grep minio-check | tail -1 | awk '{print $1}')

if [[ -n "$JOB_NAME" ]]; then
    echo "Waiting for job to complete..."
    kubectl wait --for=condition=complete --timeout=30s job/$JOB_NAME -n "$NAMESPACE" 2>/dev/null || true
    echo ""
    echo "Job output:"
    kubectl logs job/$JOB_NAME -n "$NAMESPACE" 2>/dev/null || echo "No logs yet"
    echo ""
    kubectl delete job $JOB_NAME -n "$NAMESPACE" 2>/dev/null || true
fi
