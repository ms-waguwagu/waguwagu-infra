#!/bin/bash
set -e

REGION="ap-northeast-2"
CLUSTER_NAME="T3-Wagu-Matching-EKS"

echo "[INFO] Setting up EBS CSI Driver for cluster: $CLUSTER_NAME"

# ===============================
# kubeconfig 설정
# ===============================
aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$CLUSTER_NAME"

kubectl config current-context

# ===============================
# EBS CSI addon 존재 여부 확인
# ===============================
if eksctl get addon \
  --cluster "$CLUSTER_NAME" \
  --region "$REGION" \
  | grep -q aws-ebs-csi-driver; then
  echo "[INFO] aws-ebs-csi-driver already installed"
else
  echo "[INFO] Installing aws-ebs-csi-driver addon"
  eksctl create addon \
    --name aws-ebs-csi-driver \
    --cluster "$CLUSTER_NAME" \
    --region "$REGION"
fi

# ===============================
# gp2 StorageClass 기본 설정
# ===============================
echo "[INFO] Setting gp2 as default StorageClass (if not already)"

kubectl get storageclass gp2 >/dev/null 2>&1 || {
  echo "[ERROR] gp2 StorageClass not found"
  exit 1
}

kubectl annotate storageclass gp2 \
  storageclass.kubernetes.io/is-default-class="true" \
  --overwrite

echo "[SUCCESS] EBS CSI Driver setup completed"
