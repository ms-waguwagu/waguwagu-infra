#!/bin/bash
set -e

REGION="ap-northeast-1"
PROFILE="wagu"

echo "WAGUWAGU DR SERVICE DEPLOY START (Tokyo)"

# 1. S3
echo "▶ [1/4] DR S3"
aws cloudformation deploy \
  --region $REGION \
  --profile $PROFILE \
  --stack-name T3-Wagu-S3-DR \
  --template-file ../tokyo/T3-Wagu-S3-DR.yaml

# 2. ECR
echo "▶ [2/4] DR ECR"
aws cloudformation deploy \
  --region $REGION \
  --profile $PROFILE \
  --stack-name T3-Wagu-Ecr-DR \
  --template-file ../tokyo/T3-Wagu-Ecr-DR.yaml

# 3. Valkey
echo "▶ [3/4] DR Valkey"
aws cloudformation deploy \
  --region $REGION \
  --profile $PROFILE \
  --stack-name T3-Wagu-Valkey-DR \
  --template-file ../tokyo/T3-Wagu-Valkey-DR.yaml

# 4. SQS
echo "▶ [4/4] DR SQS"
aws cloudformation deploy \
  --region $REGION \
  --profile $PROFILE \
  --stack-name T3-Wagu-Sqs-DR \
  --template-file ../tokyo/T3-Wagu-Sqs-DR.yaml \
  --parameter-overrides Environment=prod

echo "WAGUWAGU DR SERVICE DEPLOY COMPLETE"
