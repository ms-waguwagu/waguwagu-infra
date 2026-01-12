#!/bin/bash
set -e

REGION="ap-northeast-2"
MATCHING_CLUSTER="T3-Wagu-Matching-EKS"

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
MATCHING_MONITORING_DIR="$BASE_DIR/../matching/monitoring"

echo "[INFO] Switching kubeconfig to Matching cluster"
aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$MATCHING_CLUSTER"

echo "[INFO] Current kubectl context"
kubectl config current-context

echo "[INFO] Deploying Matching monitoring (Grafana + Prometheus + Loki)"

cd "$MATCHING_MONITORING_DIR"

terraform init -upgrade
terraform apply -auto-approve

echo "[DONE] Matching monitoring deployed"
echo "[NEXT] Copy Loki EXTERNAL-IP and run update-monitoring-urls.sh"
