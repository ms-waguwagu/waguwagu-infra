#!/bin/bash
set -e

# ===============================
# Args
# ===============================
TARGET="${1:-seoul}"

if [[ "$TARGET" != "seoul" && "$TARGET" != "tokyo" ]]; then
  echo "[ERROR] Usage: deploy-monitoring.sh [tokyo]"
  exit 1
fi

# ===============================
# Common
# ===============================
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="${BASE_DIR}/.."

ALERT_EMAIL="xyukyeong@naver.com"

# ===============================
# Function: ASG lookup
# ===============================
get_asg() {
  local region=$1
  local keyword=$2

  aws autoscaling describe-auto-scaling-groups \
    --region "$region" \
    --query "AutoScalingGroups[?contains(AutoScalingGroupName, '$keyword')].AutoScalingGroupName | [0]" \
    --output text
}

# ===============================
# Seoul (default)
# ===============================
if [[ "$TARGET" == "seoul" ]]; then
  REGION="ap-northeast-2"
  TEMPLATE_DIR="${ROOT_DIR}/seoul"

  CW_STACK="T3-Wagu-CloudWatch"
  CW_TEMPLATE="${TEMPLATE_DIR}/T3-Wagu-cloudwatch.yaml"

  CT_STACK="T3-Wagu-Cloudtrail"
  CT_TEMPLATE="${TEMPLATE_DIR}/T3-Wagu-Cloudtrail.yaml"

  DEPLOY_CLOUDTRAIL=true

  echo "[INFO] Deploying Seoul monitoring"
fi

# ===============================
# Tokyo (DR)
# ===============================
if [[ "$TARGET" == "tokyo" ]]; then
  REGION="ap-northeast-1"
  TEMPLATE_DIR="${ROOT_DIR}/tokyo"

  CW_STACK="T3-Wagu-CloudWatch-DR"
  CW_TEMPLATE="${TEMPLATE_DIR}/T3-Wagu-CloudWatch-DR.yaml"

  DEPLOY_CLOUDTRAIL=false

  echo "[INFO] Deploying Tokyo monitoring (CloudWatch only)"
fi

# ===============================
# ASG lookup
# ===============================
GAME_ASG=$(get_asg "$REGION" "eks-game-node-group")
MATCHING_ASG=$(get_asg "$REGION" "eks-matching-node-group")

if [[ -z "$GAME_ASG" || "$GAME_ASG" == "None" ]]; then
  echo "[ERROR] Game ASG not found in $REGION"
  exit 1
fi

if [[ -z "$MATCHING_ASG" || "$MATCHING_ASG" == "None" ]]; then
  echo "[ERROR] Matching ASG not found in $REGION"
  exit 1
fi

# ===============================
# Deploy CloudWatch
# ===============================
aws cloudformation deploy \
  --region $REGION \
  --stack-name $CW_STACK \
  --template-file $CW_TEMPLATE \
  --parameter-overrides \
    GameNodeASG=$GAME_ASG \
    MatchingNodeASG=$MATCHING_ASG \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset

# ===============================
# Deploy CloudTrail (Seoul only)
# ===============================
if [[ "$DEPLOY_CLOUDTRAIL" == true ]]; then
  aws cloudformation deploy \
    --region $REGION \
    --stack-name $CT_STACK \
    --template-file $CT_TEMPLATE \
    --parameter-overrides \
      AlertEmail=$ALERT_EMAIL \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset
fi

echo "[INFO] Monitoring deployment completed for $TARGET"
