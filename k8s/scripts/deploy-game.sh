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
# Agones 관련 리소스가 있는 디렉토리로 이동
cd "$ROOT_DIR/k8s/agones"

echo "▶ ClusterSecretStore 적용"
kubectl apply -f clustersecretstore-aws-sm.yaml
kubectl get clustersecretstore

echo "▶ Agones ExternalSecret 적용"
kubectl apply -f agones-externalsecret.yaml
kubectl get externalsecret -n game

############################
# 2. 도메인 인증 및 SSL 설정 (자동화)
############################
echo "▶ Route53 ExternalSecret 적용 (Credential Sync)"
kubectl apply -f route53-externalsecret.yaml

echo "▶ Let's Encrypt Issuer 적용"
kubectl apply -f letsencrypt-route53.yaml

# echo "▶ Wildcard Certificate 요청 (*.game.mswagu.cloud)"
echo "▶ Wildcard Certificate 요청 (*.game.waguwagu.cloud)"
kubectl apply -f game-wss-certificate.yaml

echo "⌛ 인증서 발급 대기 (최대 5분)..."
# Certificate가 Ready 상태가 될 때까지 대기합니다.
kubectl wait --for=condition=ready certificate/game-wss-wildcard -n game --timeout=300s || echo "⚠️ 인증서 발급이 지연되고 있습니다. 나중에 확인해 주세요."

############################
# 3. Karpenter 설정 적용
############################
echo "▶ Karpenter 설정 적용 (Game)"
cd "$ROOT_DIR/k8s/karpenter/game"
kubectl apply -f game-nodeclass.yaml
kubectl apply -f game-nodepool.yaml
kubectl get ec2nodeclass,nodepool

############################
# 4. Agones Fleet 적용
############################
echo "▶ Agones Fleet 적용"
kubectl apply -f agones-fleet.yaml

############################
# 4. 상태 확인
############################
echo "▶ Game 클러스터 상태 확인"
kubectl get fleet -n game
kubectl get gameserver -n game
kubectl get pods -n game
kubectl get ec2nodeclass,nodepool

echo "=============================="
echo "✅ Game 클러스터 배포 완료"
echo "=============================="
