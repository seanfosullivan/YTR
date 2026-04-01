#!/bin/bash
# Test script for file-downloader REST API service
# Usage: ./scripts/test-download.sh <youtube-url>

set -euo pipefail

NAMESPACE="${NAMESPACE:-ytr-dev}"
SERVICE_NAME="file-downloader"
PORT="${PORT:-8000}"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <youtube-url>"
    echo "Example: $0 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'"
    exit 1
fi

YOUTUBE_URL="$1"

echo "Testing file-downloader service..."
echo "Namespace: $NAMESPACE"
echo "YouTube URL: $YOUTUBE_URL"
echo ""

# Check if port-forward is needed
if ! kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Error: Service $SERVICE_NAME not found in namespace $NAMESPACE"
    echo "Make sure the service is deployed."
    exit 1
fi

# Start port-forward in background
echo "Setting up port-forward to $SERVICE_NAME:$PORT..."
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE_NAME" "$PORT:$PORT" > /dev/null 2>&1 &
PF_PID=$!

# Wait for port-forward to be ready
sleep 2

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up port-forward..."
    kill $PF_PID 2>/dev/null || true
}

trap cleanup EXIT

# Test the REST API
echo "Calling /download endpoint..."
echo ""

response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    -X POST "http://localhost:$PORT/download" \
    -H "Content-Type: application/json" \
    -d "{\"url\": \"$YOUTUBE_URL\"}")

# Extract HTTP status code
http_code=$(echo "$response" | grep "HTTP_STATUS" | cut -d: -f2)
body=$(echo "$response" | sed '/HTTP_STATUS/d')

if [ "$http_code" -eq 200 ]; then
    echo "✅ Download successful!"
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
else
    echo "❌ Error: HTTP $http_code"
    echo "$body"
    exit 1
fi

echo ""
echo ""
echo "Test complete! Check MinIO console to verify the video was uploaded."
