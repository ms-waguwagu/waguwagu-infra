#!/bin/bash
set -euo pipefail

echo "=============================="
echo "🎮 Game 클러스터 배포 시작"
echo "=============================="

SCRIPT_DIR=$(dirname "$0")
ROOT_DIR="$SCRIPT_DIR/.."

############################
# 1. Game 클러스터 리소스 배포
############################
cd "$ROOT_DIR/k8s/game"

echo "▶ ClusterSecretStore 적용"
kubectl apply -f ../clustersecretstore-aws-sm.yaml
kubectl get clustersecretstore

echo "▶ Agones ExternalSecret 적용"
kubectl apply -f agones-externalsecret.yaml
kubectl get externalsecret -n game

echo "▶ Agones Fleet 적용"
kubectl apply -f agones-fleet.yaml

############################
# 2. 상태 확인
############################
echo "▶ Game 클러스터 상태 확인"
kubectl get fleet -n game
kubectl get gameserver -n game
kubectl get pods -n game

echo "=============================="
echo "✅ Game 클러스터 배포 완료"
echo "=============================="
