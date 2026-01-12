#!/bin/bash
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

GAME_MONITORING_DIR="$BASE_DIR/../game/monitoring"
MATCHING_MONITORING_DIR="$BASE_DIR/../matching/monitoring"

REGION="ap-northeast-2"
GAME_CLUSTER="T3-Wagu-Game-EKS"
MATCHING_CLUSTER="T3-Wagu-Matching-EKS"

echo "[INFO] Destroying Game monitoring resources"

aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$GAME_CLUSTER"

kubectl config current-context

cd "$GAME_MONITORING_DIR"

terraform destroy -auto-approve || true

echo "[DONE] Game monitoring destroyed"
echo "----------------------------------------"

echo "[INFO] Destroying Matching monitoring resources"

aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$MATCHING_CLUSTER"

kubectl config current-context

cd "$MATCHING_MONITORING_DIR"

terraform destroy -auto-approve || true

echo "[DONE] Matching monitoring destroyed"
echo "----------------------------------------"

echo "[SUCCESS] All monitoring resources destroyed"
