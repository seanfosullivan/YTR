#!/bin/bash
# Script to update cluster from gRPC to REST API

set -euo pipefail

NAMESPACE="${NAMESPACE:-ytr-dev}"
REPO_ROOT="${REPO_ROOT:-$(pwd)}"
cd "$REPO_ROOT"

echo "=========================================="
echo "Updating Cluster to REST API"
echo "=========================================="
echo ""

# Step 1: Rebuild Docker image
echo "Step 1: Rebuilding Docker image with REST server..."
eval "$(minikube docker-env)"
docker build -t file-downloader:v1 services/python/FileDownloader

echo ""
echo "✅ Docker image rebuilt"

# Step 2: Update Helm deployment
echo ""
echo "Step 2: Updating Helm deployment..."
echo "Using values files (in order, later overrides earlier):"
echo "  1. infra/helm/platform/values.yaml (base)"
echo "  2. infra/helm/platform/values-dev.yaml (dev overrides)"
echo ""

helm upgrade dev-platform infra/helm/platform \
  -n "$NAMESPACE" \
  -f infra/helm/platform/values.yaml \
  -f infra/helm/platform/values-dev.yaml

echo ""
echo "✅ Helm deployment updated"

# Step 3: Wait for rollout
echo ""
echo "Step 3: Waiting for rollout to complete..."
kubectl rollout status deployment/file-downloader -n "$NAMESPACE" --timeout=300s

echo ""
echo "✅ Rollout complete"

# Step 4: Verify
echo ""
echo "Step 4: Verifying deployment..."
echo ""
echo "Service ports:"
kubectl get svc file-downloader -n "$NAMESPACE" -o jsonpath='{.spec.ports[*].port}' && echo ""

echo ""
echo "Pod status:"
kubectl get pods -n "$NAMESPACE" -l app=file-downloader

echo ""
echo "=========================================="
echo "Update Complete!"
echo "=========================================="
