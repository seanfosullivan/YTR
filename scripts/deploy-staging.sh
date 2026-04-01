#!/bin/bash
# Safe deployment script for STAGING environment

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
cd "$REPO_ROOT"

ENVIRONMENT="staging"
NAMESPACE="ytr-staging"
RELEASE_NAME="staging-platform"
PLATFORM_CHART_PATH="infra/helm/platform"

# Safety check
if [[ "${NAMESPACE}" != *"staging"* ]]; then
    echo "❌ ERROR: This script only deploys to STAGING environment"
    exit 1
fi

echo "=========================================="
echo "Deploying to STAGING Environment"
echo "=========================================="
echo ""
echo "Environment: ${ENVIRONMENT}"
echo "Namespace:   ${NAMESPACE}"
echo "Release:     ${RELEASE_NAME}"
echo ""

read -p "Deploy to STAGING? (yes/no): " confirm
if [[ "${confirm}" != "yes" ]]; then
    echo "Deployment cancelled."
    exit 0
fi

if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
    echo "Creating namespace ${NAMESPACE}..."
    kubectl create namespace "${NAMESPACE}"
fi

echo ""
echo "Deploying with values:"
echo "  1. ${PLATFORM_CHART_PATH}/values.yaml (base)"
echo "  2. ${PLATFORM_CHART_PATH}/values-staging.yaml (staging overrides)"
echo ""

helm upgrade --install "${RELEASE_NAME}" "${PLATFORM_CHART_PATH}" \
  -n "${NAMESPACE}" \
  -f "${PLATFORM_CHART_PATH}/values.yaml" \
  -f "${PLATFORM_CHART_PATH}/values-staging.yaml" \
  --create-namespace \
  --wait \
  --timeout 10m

echo ""
echo "✅ STAGING deployment complete!"
