#!/usr/bin/env bash
set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

echo "[K8S] Matching 삭제"
cd k8s/matching
kubectl delete -f . --ignore-not-found

echo "[K8S] Game 삭제"
cd ../game/agones
kubectl delete -f . --ignore-not-found
helm uninstall agones -n agones-system || true
