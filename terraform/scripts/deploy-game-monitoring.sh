#!/bin/bash
set -e

REGION="ap-northeast-2"
GAME_CLUSTER="T3-Wagu-Game-EKS"

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_MONITORING_DIR="$BASE_DIR/../game/monitoring"

echo "[INFO] Switching kubeconfig to Game cluster"
aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$GAME_CLUSTER"

echo "[INFO] Current kubectl context"
kubectl config current-context

echo "[INFO] Deploying Game monitoring (Prometheus only)"

cd "$GAME_MONITORING_DIR"

terraform init -upgrade
terraform apply -auto-approve

echo "[DONE] Game monitoring deployed"
echo "[NEXT] Copy Prometheus EXTERNAL-IP and run update-monitoring-urls.sh"
