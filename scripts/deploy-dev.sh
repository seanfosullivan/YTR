#!/bin/bash
# Safe deployment script for DEV environment
# This script explicitly deploys to dev and prevents accidental prod deployments

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
cd "$REPO_ROOT"

ENVIRONMENT="dev"
NAMESPACE="ytr-dev"
RELEASE_NAME="dev-platform"
PLATFORM_CHART_PATH="infra/helm/platform"

# Safety check - ensure we're deploying to dev
if [[ "${NAMESPACE}" != *"dev"* ]]; then
    echo "❌ ERROR: This script only deploys to DEV environment"
    echo "   Namespace must contain 'dev'"
    exit 1
fi

echo "=========================================="
echo "Deploying to DEV Environment"
echo "=========================================="
echo ""
echo "Environment: ${ENVIRONMENT}"
echo "Namespace:   ${NAMESPACE}"
echo "Release:     ${RELEASE_NAME}"
echo ""

# Confirm deployment
read -p "Deploy to DEV environment? (yes/no): " confirm
if [[ "${confirm}" != "yes" ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Ensure namespace exists
if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
    echo "Creating namespace ${NAMESPACE}..."
    kubectl create namespace "${NAMESPACE}"
fi

# Deploy with explicit dev values
echo ""
echo "Deploying with values:"
echo "  1. ${PLATFORM_CHART_PATH}/values.yaml (base)"
echo "  2. ${PLATFORM_CHART_PATH}/values-dev.yaml (dev overrides)"
echo ""

helm upgrade --install "${RELEASE_NAME}" "${PLATFORM_CHART_PATH}" \
  -n "${NAMESPACE}" \
  -f "${PLATFORM_CHART_PATH}/values.yaml" \
  -f "${PLATFORM_CHART_PATH}/values-dev.yaml" \
  --create-namespace \
  --wait \
  --timeout 10m

echo ""
echo "✅ DEV deployment complete!"
echo ""
echo "Verify with:"
echo "  kubectl get pods -n ${NAMESPACE}"
