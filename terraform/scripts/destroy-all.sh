#!/usr/bin/env bash
set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

echo "=============================="
echo "1. Kubernetes Matching 삭제"
echo "=============================="

cd k8s/matching
kubectl delete -f matching-hpa.yaml --ignore-not-found
kubectl delete -f matching-ingress.yaml --ignore-not-found
kubectl delete -f matching-deploy.yaml --ignore-not-found
kubectl delete -f matching-service.yaml --ignore-not-found
kubectl delete -f matching-externalsecret.yaml --ignore-not-found
kubectl delete -f matching-namespace.yaml --ignore-not-found
kubectl get all -n matching || true

echo "=============================="
echo "2. Kubernetes Game(Agones) 삭제"
echo "=============================="

cd ../game/agones
kubectl delete -f agones-fleet.yaml --ignore-not-found
kubectl delete -f agones-externalsecret.yaml --ignore-not-found
helm uninstall agones -n agones-system || true
kubectl get all -n game || true

echo "=============================="
echo "3. Terraform Seoul 리전 삭제"
echo "=============================="

cd "$ROOT_DIR/terraform/matching"
terraform destroy -var-file=terraform.seoul.tfvars -auto-approve

cd "$ROOT_DIR/terraform/game"
terraform destroy -var-file=terraform.seoul.tfvars -auto-approve

echo "=============================="
echo "4. Terraform Tokyo 리전 삭제"
echo "=============================="

cd "$ROOT_DIR/terraform/matching"
terraform destroy -var-file=terraform.tokyo.tfvars -auto-approve

cd "$ROOT_DIR/terraform/game"
terraform destroy -var-file=terraform.tokyo.tfvars -auto-approve

echo "=============================="
echo "전체 리소스 삭제 완료"
echo "=============================="
