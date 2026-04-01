#!/bin/bash
# Script to access MinIO console and verify downloads

set -euo pipefail

NAMESPACE="${NAMESPACE:-ytr-dev}"
CONSOLE_PORT="${CONSOLE_PORT:-9091}"

echo "=========================================="
echo "Accessing MinIO Console"
echo "=========================================="
echo ""

# Check if MinIO service exists
if ! kubectl get svc -n "$NAMESPACE" | grep -q minio; then
    echo "❌ Error: MinIO service not found in namespace $NAMESPACE"
    exit 1
fi

# Get MinIO service name
MINIO_SERVICE=$(kubectl get svc -n "$NAMESPACE" | grep minio | awk '{print $1}' | head -1)

echo "MinIO Service: $MINIO_SERVICE"
echo "Namespace: $NAMESPACE"
echo ""

# Check if port is already in use
if lsof -i :$CONSOLE_PORT &>/dev/null; then
    echo "⚠️  Port $CONSOLE_PORT is already in use"
    echo "   Using existing port-forward..."
else
    echo "Starting port-forward to MinIO console..."
    kubectl port-forward -n "$NAMESPACE" "svc/$MINIO_SERVICE" "$CONSOLE_PORT:9090" > /dev/null 2>&1 &
    PF_PID=$!
    sleep 2
    echo "✅ Port-forward started"
fi

echo ""
echo "=========================================="
echo "MinIO Console Access"
echo "=========================================="
echo ""
echo "🌐 Open in browser: http://localhost:$CONSOLE_PORT"
echo ""
echo "📋 Login Credentials:"
echo "   Username: minioadmin"
echo "   Password: minioadmin"
echo ""
echo "📦 Bucket to check:"
BUCKET=$(kubectl get deployment file-downloader -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="RAW_VIDEOS_BUCKET")].value}' 2>/dev/null || echo "raw-videos-dev")
echo "   $BUCKET"
echo ""
echo "💡 Steps:"
echo "   1. Login to MinIO console"
echo "   2. Click on 'Buckets' in left sidebar"
echo "   3. Click on '$BUCKET' bucket"
echo "   4. You should see your downloaded video files"
echo ""
echo "Press Ctrl+C to stop port-forward when done"

# Cleanup function
cleanup() {
    if [[ -n "${PF_PID:-}" ]]; then
        echo ""
        echo "Stopping port-forward..."
        kill $PF_PID 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

# Wait for user interrupt
wait
