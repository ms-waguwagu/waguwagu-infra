#!/bin/bash
set -e

REGION="ap-northeast-1"
PROFILE="wagu"

echo "WAGUWAGU DR CORE DEPLOY START (Tokyo)"

# 1. Network (VPC / Subnet / Route / Peering)
echo "▶ [1/3] DR Network"
aws cloudformation deploy \
  --region $REGION \
  --profile $PROFILE \
  --stack-name T3-Wagu-Network-Tokyo \
  --template-file DR/T3-Wagu-Network-Tokyo.yaml

# 2. Security Groups
echo "▶ [2/3] DR Security Groups"
aws cloudformation deploy \
  --region $REGION \
  --profile $PROFILE \
  --stack-name T3-Wagu-Security-Group-Tokyo \
  --template-file DR/T3-Wagu-Security-Group-Tokyo.yaml

# 3. Aurora Global DB (Secondary)
echo "▶ [3/3] DR Aurora Global DB"
aws cloudformation deploy \
  --region $REGION \
  --profile $PROFILE \
  --stack-name T3-Wagu-DB-Tokyo \
  --template-file DR/T3-Wagu-DB-Tokyo.yaml

echo "WAGUWAGU DR CORE DEPLOY COMPLETE"
