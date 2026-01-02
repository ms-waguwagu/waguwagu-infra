#!/bin/bash
set -e

TARGET_REGION=${1:-seoul}

if [ "$TARGET_REGION" = "seoul" ]; then
  echo "서울 리전으로 전환"
  AWS_REGION="ap-northeast-2"
  EKS_CTX="arn:aws:eks:ap-northeast-2:061039804626:cluster/T3-Wagu-Matching-EKS"

elif [ "$TARGET_REGION" = "tokyo" ]; then
  echo "DR 발동 — 도쿄 리전"
  AWS_REGION="ap-northeast-1"
  EKS_CTX="arn:aws:eks:ap-northeast-1:061039804626:cluster/T3-Wagu-DR-Matching-EKS"

else
  echo "지원 안 하는 리전"
  exit 1
fi

echo "▶ EKS 컨텍스트 전환"
kubectl config use-context "$EKS_CTX"

echo "▶ matching-ingress ALB 대기"
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  ingress/matching-ingress -n matching --timeout=10m

MATCHING_DNS=$(kubectl get ingress matching-ingress -n matching \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Matching ALB: $MATCHING_DNS"

echo "▶ CloudFront 배포"
aws cloudformation deploy \
  --template-file T3-Wagu-Cloudfront.yaml \
  --stack-name T3-Wagu-Cloudfront \
  --parameter-overrides \
    MatchingAlbDns=$MATCHING_DNS \
  --capabilities CAPABILITY_NAMED_IAM \
	--profile wagu
