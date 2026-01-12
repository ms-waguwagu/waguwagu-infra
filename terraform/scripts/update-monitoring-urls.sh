#!/bin/bash
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

GAME_PROM_VALUES="$BASE_DIR/../matching/monitoring/grafana-values.yaml"
GAME_PROMTAIL_VALUES="$BASE_DIR/../game/monitoring/promtail-values.yaml"

echo "[INPUT] Enter Game Prometheus URL"
read -r GAME_PROM_URL

echo "[INPUT] Enter Matching Loki URL (without /loki/api/v1/push)"
read -r MATCHING_LOKI_URL

echo "[INFO] Updating Grafana datasource (Prometheus-Game)"
sed -i '' \
  "s|url: http.*elb.*|url: $GAME_PROM_URL|g" \
  "$GAME_PROM_VALUES"

echo "[INFO] Updating Promtail Loki client URL"
sed -i '' \
  "s|url: http.*:3100/loki/api/v1/push|url: $MATCHING_LOKI_URL:3100/loki/api/v1/push|g" \
  "$GAME_PROMTAIL_VALUES"

echo "[DONE] URLs updated successfully"
echo "[NEXT]"
echo "1. cd terraform/game/monitoring && terraform apply"
echo "2. cd terraform/matching/monitoring && terraform apply"
