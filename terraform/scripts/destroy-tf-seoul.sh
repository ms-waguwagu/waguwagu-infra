#!/usr/bin/env bash
set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

cd "$ROOT_DIR/terraform/matching"
terraform destroy -var-file=terraform.seoul.tfvars -auto-approve

cd "$ROOT_DIR/terraform/game"
terraform destroy -var-file=terraform.seoul.tfvars -auto-approve
