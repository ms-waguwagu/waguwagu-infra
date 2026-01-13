#!/bin/bash
set -euo pipefail

echo "=============================="
echo "🚀 Matching 클러스터 배포 시작"
echo "=============================="

# 1. 작업 디렉토리 이동
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR/../k8s/matching"

# 2. ClusterSecretStore 적용
echo "▶ ClusterSecretStore 적용"
kubectl apply -f ../clustersecretstore-aws-sm.yaml
kubectl get clustersecretstore

# 3. ExternalSecret 적용
echo "▶ matching ExternalSecret 적용"
kubectl apply -f matching-externalsecret.yaml
kubectl get externalsecret -n matching

# 4. Service 적용
echo "▶ matching Service 적용"
kubectl apply -f matching-service.yaml
kubectl get svc -n matching

# 5. Ingress 적용
echo "▶ matching Ingress 적용"
kubectl apply -f matching-ingress.yaml
kubectl get ingress -n matching

# 6. Allocator Endpoint 조회
echo "▶ Game 클러스터로 전환 (Allocator 조회)"
aws eks update-kubeconfig \
  --region ap-northeast-2 \
  --name T3-Wagu-Game-EKS

AGONES_ALLOCATOR_ENDPOINT=$(kubectl get svc agones-allocator \
  -n agones-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$AGONES_ALLOCATOR_ENDPOINT" ]; then
  echo "❌ AGONES_ALLOCATOR_ENDPOINT 조회 실패"
  exit 1
fi

echo "✔ Allocator Endpoint: $AGONES_ALLOCATOR_ENDPOINT"

# 7. Matching 클러스터로 복귀
echo "▶ Matching 클러스터로 복귀"
aws eks update-kubeconfig \
  --region ap-northeast-2 \
  --name T3-Wagu-Matching-EKS

# 8. matching-deploy.yaml에 AGONES_ALLOCATOR_ENDPOINT 자동 반영
echo "▶ matching-deploy.yaml에 AGONES_ALLOCATOR_ENDPOINT 자동 반영"

sed -i.bak \
  "s|AGONES_ALLOCATOR_ENDPOINT:.*|AGONES_ALLOCATOR_ENDPOINT: $AGONES_ALLOCATOR_ENDPOINT|g" \
  matching-deploy.yaml


# 9. mTLS 설정
echo "▶ mTLS 설정 실행"
cd ../agones/mtls
./setup-mtls.sh

# 10. Matching Server 배포
echo "▶ Matching Server Deployment 적용"
cd ../../matching
kubectl apply -f matching-deploy.yaml

# 11. Karpenter 설정 적용
echo "▶ Karpenter 설정 적용 (Matching)"
cd "$SCRIPT_DIR/../k8s/karpenter/matching"
kubectl apply -f matching-nodeclass.yaml
kubectl apply -f matching-nodepool.yaml
kubectl get ec2nodeclass,nodepool

# 12. HPA 적용
echo "▶ HPA 적용"
cd "$SCRIPT_DIR/../k8s/matching"
kubectl apply -f matching-hpa.yaml
kubectl get hpa -n matching

echo "=============================="
echo "✅ Matching 클러스터 배포 완료"
echo "=============================="
