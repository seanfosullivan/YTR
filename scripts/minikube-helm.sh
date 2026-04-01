#!/bin/bash
set -euo pipefail

# This script sets up a local dev environment on minikube using Helm
# It assumes you have minikube, kubectl, helm, and Docker installed.

# Optional: allow running from anywhere as long as REPO_ROOT is set
if [[ -n "${REPO_ROOT:-}" ]]; then
  cd "$REPO_ROOT"
fi

NAMESPACE="ytr-dev"
RELEASE_NAME="dev-platform"
PLATFORM_CHART_PATH="infra/helm/platform"

cleanup() {
  echo "[cleanup] Uninstalling Helm release ${RELEASE_NAME} in namespace ${NAMESPACE} (if present)..."
  helm uninstall "${RELEASE_NAME}" -n "${NAMESPACE}" 2>/dev/null || true

  echo "[cleanup] Deleting namespace ${NAMESPACE} (if present)..."
  kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true || true

  echo "[cleanup] Done."
}

if [[ "${1:-}" == "--cleanup" || "${1:-}" == "-c" ]]; then
  cleanup
  exit 0
fi

echo "[minikube] Starting minikube (idempotent)..."
minikube start

echo "[minikube] Enabling ingress addon..."
minikube addons enable ingress

echo "[ingress] Waiting for ingress-nginx controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  -l app.kubernetes.io/component=controller \
  --timeout=180s || true

echo "[kubectl] Switching context to minikube..."
kubectl config use-context minikube

echo "[docker] Using minikube's Docker daemon..."
eval "$(minikube docker-env)"

# Build local images that Helm deployments will reference
# Adjust the image name/tag to match your service chart values.
echo "[docker] Building file-downloader image for local dev..."
docker build -t file-downloader:v1 services/python/FileDownloader

echo "[docker] Building rss-feed image for local dev..."
docker build -t rss-feed:v1 services/python/RssFeedService

# Add Prometheus community Helm repository for monitoring stack
echo "[helm] Adding prometheus-community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

# Prepare Helm dependencies
if [[ -d "${PLATFORM_CHART_PATH}" ]]; then
  echo "[helm] Updating platform chart dependencies..."
  helm dependency update "${PLATFORM_CHART_PATH}"
else
  echo "[error] Platform chart path not found: ${PLATFORM_CHART_PATH}" >&2
  exit 1
fi

# Ensure Prometheus Operator CRDs are installed first
# The kube-prometheus-stack chart should do this, but sometimes we need to ensure it happens
echo "[helm] Checking for Prometheus Operator CRDs..."
if ! kubectl get crd prometheuses.monitoring.coreos.com &>/dev/null; then
  echo "[helm] Prometheus CRDs not found. Installing kube-prometheus-stack with CRDs first..."
  # Install the chart with --create-namespace and let it install CRDs
  # We'll do a dry-run first to see if CRDs get installed, then do the real install
  helm upgrade --install "${RELEASE_NAME}" "${PLATFORM_CHART_PATH}" \
    -n "${NAMESPACE}" \
    -f "${PLATFORM_CHART_PATH}/values.yaml" \
    -f "${PLATFORM_CHART_PATH}/values-dev.yaml" \
    --create-namespace \
    --wait \
    --timeout 10m || {
    echo "[warning] First install attempt failed, this is normal if CRDs need to be installed"
    echo "[helm] Waiting for CRDs to be available..."
    sleep 10
  }
fi

# Ensure target namespace exists (do not fail if it already exists)
if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "[kubectl] Creating namespace ${NAMESPACE}..."
  kubectl create namespace "${NAMESPACE}"
fi

# Ensure Prometheus Operator CRDs are installed first
echo "[helm] Checking for Prometheus Operator CRDs..."
if ! kubectl get crd prometheuses.monitoring.coreos.com &>/dev/null; then
  echo "[helm] Prometheus CRDs not found. Installing them first..."
  # Install CRDs from the kube-prometheus-stack chart
  # The chart should handle this, but we'll ensure it happens
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"
  
  # Pull the chart to extract CRDs
  helm pull prometheus-community/kube-prometheus-stack --version 61.0.0 --untar 2>/dev/null || {
    echo "[helm] Could not pull chart for CRDs. Will let Helm install them..."
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
  }
  
  if [[ -d "kube-prometheus-stack/crds" ]]; then
    echo "[helm] Installing CRDs from chart..."
    kubectl apply -f kube-prometheus-stack/crds/ --server-side 2>/dev/null || kubectl apply -f kube-prometheus-stack/crds/
    echo "[helm] Waiting for CRDs to be ready..."
    sleep 5
  fi
  
  cd - > /dev/null
  rm -rf "$TEMP_DIR"
else
  echo "[helm] ✅ Prometheus CRDs already installed"
fi

# Install/upgrade the umbrella chart into the dev namespace
echo "[helm] Deploying ${RELEASE_NAME} into namespace ${NAMESPACE} using dev values..."
helm upgrade --install "${RELEASE_NAME}" "${PLATFORM_CHART_PATH}" \
  -n "${NAMESPACE}" \
  -f "${PLATFORM_CHART_PATH}/values.yaml" \
  -f "${PLATFORM_CHART_PATH}/values-dev.yaml" \
  --create-namespace \
  --wait \
  --timeout 10m

echo "[helm] Deployment triggered. Current resources in ${NAMESPACE}:"
kubectl get pods,svc -n "${NAMESPACE}" || true

echo "[info] Local dev environment is being brought up. You can watch with:"
echo "       kubectl get pods -n ${NAMESPACE} -w"
