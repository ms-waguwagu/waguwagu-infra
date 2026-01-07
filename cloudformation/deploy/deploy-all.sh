#!/bin/bash
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SEOUL_DIR="$BASE_DIR/seoul"

TOTAL=9
CURRENT=0

step () {
  CURRENT=$((CURRENT+1))
  echo ""
  echo "=============================="
  echo "[$CURRENT/$TOTAL] $1"
  echo "=============================="
}

# 1. Network
step "Network 배포"
aws cloudformation deploy \
  --stack-name T3-Wagu-Network \
  --template-file "$SEOUL_DIR/T3-Wagu-Network.yaml" \
  --capabilities CAPABILITY_NAMED_IAM

# 2. Security Group
step "Security Group 배포"
aws cloudformation deploy \
  --stack-name T3-Wagu-Security-Group \
  --template-file "$SEOUL_DIR/T3-Wagu-Security-Group.yaml" \
  --capabilities CAPABILITY_NAMED_IAM

# 3. Valkey
step "Valkey 배포"
aws cloudformation deploy \
  --stack-name T3-Wagu-Valkey \
  --template-file "$SEOUL_DIR/T3-Wagu-Valkey.yaml" \
  --capabilities CAPABILITY_NAMED_IAM

# 4. DB
step "DB 배포"
aws cloudformation deploy \
  --stack-name T3-Wagu-DB \
  --template-file "$SEOUL_DIR/T3-Wagu-DB.yaml" \
  --parameter-overrides MasterPassword='MysqlPass123!'

# 5. ECR
step "ECR 배포"
aws cloudformation deploy \
  --stack-name T3-Wagu-Ecr \
  --template-file "$SEOUL_DIR/T3-Wagu-Ecr.yaml" \
  --capabilities CAPABILITY_NAMED_IAM

# 6. S3
step "S3 배포"
aws cloudformation deploy \
  --stack-name T3-Wagu-S3 \
  --template-file "$SEOUL_DIR/T3-Wagu-S3.yaml" \
  --capabilities CAPABILITY_NAMED_IAM

# 7. Jenkins
step "Jenkins 배포"
aws cloudformation deploy \
  --stack-name T3-Wagu-Jenkins \
  --template-file "$SEOUL_DIR/T3-Wagu-Jenkins.yaml" \
  --parameter-overrides \
    JenkinsAdminUser=t3-wagu-jenkins \
    JenkinsAdminPassword=qwer1234! \
  --capabilities CAPABILITY_NAMED_IAM

# 8. SQS
step "SQS 배포"
aws cloudformation deploy \
  --stack-name T3-Wagu-SQS \
  --template-file "$SEOUL_DIR/T3-Wagu-Sqs.yaml" \
  --capabilities CAPABILITY_NAMED_IAM \
  --profile wagu

# 9. CloudTrail
step "CloudTrail 배포"
aws cloudformation deploy \
  --stack-name T3-Wagu-Cloudtrail \
  --template-file "$SEOUL_DIR/T3-Wagu-Cloudtrail.yaml" \
  --capabilities CAPABILITY_NAMED_IAM \
  --profile wagu

echo ""
echo "=============================="
echo "[${TOTAL}/${TOTAL}] 전체 배포 완료"
echo "=============================="
