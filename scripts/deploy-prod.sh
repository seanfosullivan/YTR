#!/bin/bash
# SAFE deployment script for PRODUCTION environment
# This script has multiple safety checks to prevent accidental prod deployments

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
cd "$REPO_ROOT"

ENVIRONMENT="prod"
NAMESPACE="ytr"
RELEASE_NAME="prod-platform"
PLATFORM_CHART_PATH="infra/helm/platform"

# Safety check 1: Ensure we're deploying to prod namespace
if [[ "${NAMESPACE}" == *"dev"* ]] || [[ "${NAMESPACE}" == *"staging"* ]]; then
    echo "❌ ERROR: This script only deploys to PRODUCTION"
    echo "   Detected non-prod namespace: ${NAMESPACE}"
    exit 1
fi

# Safety check 2: Require explicit environment variable
if [[ "${DEPLOY_TO_PROD:-}" != "true" ]]; then
    echo "❌ ERROR: Production deployment requires explicit confirmation"
    echo ""
    echo "To deploy to production, set DEPLOY_TO_PROD=true:"
    echo "  DEPLOY_TO_PROD=true bash scripts/deploy-prod.sh"
    echo ""
    exit 1
fi

# Safety check 3: Check current kubectl context
CURRENT_CONTEXT=$(kubectl config current-context)
echo "=========================================="
echo "⚠️  PRODUCTION DEPLOYMENT"
echo "=========================================="
echo ""
echo "Environment:  ${ENVIRONMENT}"
echo "Namespace:    ${NAMESPACE}"
echo "Release:      ${RELEASE_NAME}"
echo "Kube Context: ${CURRENT_CONTEXT}"
echo ""
echo "⚠️  WARNING: You are about to deploy to PRODUCTION!"
echo ""

# Safety check 4: Require explicit confirmation
read -p "Type 'DEPLOY PROD' to confirm: " confirm
if [[ "${confirm}" != "DEPLOY PROD" ]]; then
    echo "❌ Deployment cancelled. Confirmation text did not match."
    exit 1
fi

# Safety check 5: Dry-run first
echo ""
echo "Running dry-run to preview changes..."
echo ""

helm upgrade --install "${RELEASE_NAME}" "${PLATFORM_CHART_PATH}" \
  -n "${NAMESPACE}" \
  -f "${PLATFORM_CHART_PATH}/values.yaml" \
  -f "${PLATFORM_CHART_PATH}/values-prod.yaml" \
  --create-namespace \
  --dry-run \
  --debug > /tmp/helm-prod-dry-run.txt 2>&1

echo "Dry-run complete. Review the output above."
echo ""
read -p "Proceed with actual deployment? (yes/no): " proceed
if [[ "${proceed}" != "yes" ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Safety check 6: Final confirmation
echo ""
echo "⚠️  FINAL CONFIRMATION"
read -p "Deploy to PRODUCTION now? Type 'YES' (all caps): " final
if [[ "${final}" != "YES" ]]; then
    echo "❌ Deployment cancelled."
    exit 1
fi

# Actual deployment
echo ""
echo "Deploying to PRODUCTION..."
echo ""

helm upgrade --install "${RELEASE_NAME}" "${PLATFORM_CHART_PATH}" \
  -n "${NAMESPACE}" \
  -f "${PLATFORM_CHART_PATH}/values.yaml" \
  -f "${PLATFORM_CHART_PATH}/values-prod.yaml" \
  --create-namespace \
  --wait \
  --timeout 15m

echo ""
echo "✅ PRODUCTION deployment complete!"
echo ""
echo "Verify with:"
echo "  kubectl get pods -n ${NAMESPACE}"
