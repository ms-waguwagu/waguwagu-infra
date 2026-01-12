

---

# waguwagu-infra 배포 가이드

**(Terraform + CloudFormation 기반 인프라 운영 문서)**

이 문서는 **WAGUWAGU 서비스 인프라의 배포, 운영, 삭제 절차**를 정리한다.
인프라는 **AWS CloudFormation + Terraform + Kubernetes(EKS)** 기반으로 구성되어 있다.

* **메인 리전**: 서울 (`ap-northeast-2`)
* **DR 리전**: 도쿄 (`ap-northeast-1`)

---

## 📚 목차

### CloudFormation

1. [사전 준비](#1-사전-준비)
2. [CloudFormation 배포 위치](#2-cloudformation-배포-위치)
3. [CloudFormation 전체 자동 배포 (서울)](#3-cloudformation-전체-자동-배포-서울-리전)
4. [CloudFront 배포](#4-cloudfront-배포)
5. [CloudWatch 및 CloudTrail 배포](#5-cloudwatch-및-cloudtrail-배포)
6. [DR (도쿄 리전) 운영 절차](#6-dr-도쿄-리전-운영-절차)

### Terraform / Kubernetes

0. [사전 준비](#0-사전-준비)
1. [Terraform 초기화](#1-terraform-초기화)
2. [EKS 클러스터 선배포](#2-eks-클러스터-선배포-필수)
3. [Terraform 전체 배포](#3-terraform-전체-배포)
4. [kubectl 컨텍스트 전환](#4-kubectl-컨텍스트-전환)
5. [Karpenter 설정 (Matching)](#5-karpenter-설정-matching)
6. [Kubernetes 리소스 배포](#6-kubernetes-리소스-배포-권장)
7. [Monitoring 배포](#7-monitoring-배포)
8. [Kubernetes 리소스 삭제](#8-kubernetes-리소스-삭제-자동화)
9. [Terraform 리소스 삭제](#9-terraform-리소스-삭제-자동화)
10. [mTLS 설정 (Matching ↔ Game 서버 통신)](#10-mtls-설정-matching--game-서버-통신)

---

# ☁️ CloudFormation

## 1. 사전 준비

### AWS CLI 설정 (서울 리전 기준)

```bash
aws configure
# Default region: ap-northeast-2
# Output format: json
```

---

## 2. CloudFormation 배포 위치

모든 CloudFormation 스크립트는 아래 디렉토리에서 실행한다.

```bash
waguwagu-infra/cloudformation/deploy
```

---

## 3. CloudFormation 전체 자동 배포 (서울 리전)

서울 리전의 **공통 인프라(VPC, IAM, 기본 리소스)** 를 일괄 배포한다.

```bash
./deploy-all.sh
```

### 권장 배포 흐름

1. `deploy-all.sh` → 공통 인프라 배포
2. Terraform → EKS 클러스터 생성
3. CloudWatch 배포 → ASG 확인 후 실행
4. CloudFront 배포 → Ingress/ALB 생성 후 실행

---

## 4. CloudFront 배포

**서울 리전**

```bash
./deploy-cloudfront.sh
```

**도쿄 리전 (DR)**

```bash
./deploy-cloudfront.sh tokyo
```

> ⚠️ Ingress 생성 후 ALB DNS가 준비된 상태여야 한다.

---

## 5. CloudWatch 및 CloudTrail 배포

**서울 리전**

```bash
./deploy-monitoring.sh
```
> CloudWatch 및 CloudTrail 배포

**도쿄 리전 (DR)**

```bash
./deploy-monitoring.sh tokyo
```
> CloudWatch만 배포
---

## 6. DR (도쿄 리전) 운영 절차

### 기본 인프라 배포 (항상 실행)

```bash
./deploy-dr-core.sh
```

### 장애 발생 시에만 실행

```bash
./deploy-dr-services.sh
```

DR 클러스터 생성 완료 후 CloudFront 배포:

```bash
./deploy-cloudfront.sh tokyo
```

---

# 🧱 Terraform / Kubernetes

## 0. 사전 준비

### 작업 위치

```bash
# Matching
cd waguwagu-infra/terraform/matching

# Game
cd waguwagu-infra/terraform/game
```

---

## 1. Terraform 초기화

```bash
terraform init
```

---

## 2. EKS 클러스터 선배포 (필수)

> ⚠️ EKS가 없으면 helm/kubernetes 리소스가 실패한다.

```bash
terraform apply \
  -target="module.eks" \
  -var-file=terraform.seoul.tfvars \
  -auto-approve
```

(DR)

```bash
terraform apply \
  -target="module.eks" \
  -var-file=terraform.tokyo.tfvars \
  -auto-approve
```

---

## 3. Terraform 전체 배포

```bash
terraform apply \
  -var-file=terraform.seoul.tfvars \
  -auto-approve
```

(DR)

```bash
terraform apply \
  -var-file=terraform.tokyo.tfvars \
  -auto-approve
```

---

## 4. kubectl 컨텍스트 전환

```bash
kubectl config current-context
kubectl get nodes
```

```bash
kubectl config use-context arn:aws:eks:ap-northeast-2:061039804626:cluster/T3-Wagu-Matching-EKS
kubectl config use-context arn:aws:eks:ap-northeast-2:061039804626:cluster/T3-Wagu-Game-EKS
```

---

## 5. Karpenter 설정 (Matching)

```bash
cd waguwagu-infra/k8s/karpenter/matching

kubectl apply -f matching-nodeclass.yaml
kubectl apply -f matching-nodepool.yaml
kubectl get ec2nodeclass,nodepool
```

---

## 6. Kubernetes 리소스 배포 (권장)

### Matching

```bash
cd waguwagu-infra
./scripts/deploy-matching.sh
```

### Game

```bash
cd waguwagu-infra
./scripts/deploy-game.sh
```

---
## 7. Monitoring 배포

실행 위치
```bash
cd waguwagu-infra/terraform/scripts
```

**7-1. EBS CSI Driver 설치 (필수, 1회)**
```bash
./setup-ebs-csi.sh
```

**7-2. Game Monitoring 배포**
```bash
./deploy-game-monitoring.sh
```

> Prometheus EXTERNAL-IP 복사

**7-3. Matching Monitoring 배포**
```bash
./deploy-matching-monitoring.sh
```

> Loki EXTERNAL-IP 복사

**7-4. Monitoring URL 반영**
```bash
./update-monitoring-urls.sh
```

**7-5. Monitoring 재적용**
```bash
cd ../game/monitoring
terraform apply -auto-approve

cd ../../matching/monitoring
terraform apply -auto-approve
```

**7-6. Monitoring 삭제**
```bash
./destroy-monitoring.sh
```
---

## 8. Kubernetes 리소스 삭제 (자동화)

```bash
cd waguwagu-infra
./scripts/destroy-k8s.sh
```

---

## 9. Terraform 리소스 삭제 (자동화)

```bash
cd waguwagu-infra
./scripts/destroy-all.sh
```

---


## 10. mTLS 설정 (Matching ↔ Game 서버 통신)

Matching 서버와 Game 서버 간 **내부 통신 보안 강화를 위해 mTLS를 사용**한다.
mTLS 설정은 **Terraform 및 기본 Kubernetes 리소스 배포 이후**에 수행해야 한다.

---

### 사전 조건

아래 작업이 **모두 완료된 상태**여야 한다.

* Matching / Game 클러스터 **Terraform `apply` 완료**
* 각 클러스터의 **Namespace 생성 완료**

  * Matching: `matching`
  * Game: `game`, `agones`
* **Agones Fleet 배포 완료**

> ⚠️ 현재 Namespace 생성은 수동이며, 추후 자동화 예정

---

### mTLS 설정 절차

#### 1️⃣ mTLS 스크립트 위치로 이동

```bash
cd waguwagu-infra/k8s/game/agones/mtls
```

---

#### 2️⃣ mTLS 인증서 및 Secret 자동 생성

```bash
./setup-mtls.sh
```

해당 스크립트는 다음 작업을 자동 수행한다.

* Root CA / Server / Client 인증서 생성
* Game / Matching Namespace에 Kubernetes Secret 생성
* mTLS 통신을 위한 기본 인증 구조 구성

---

#### 3️⃣ Matching Deployment 적용

mTLS Secret이 생성된 이후에 **Matching 서버 Deployment를 적용**해야 한다.

```bash
kubectl apply -f waguwagu-infra/k8s/matching/matching-deploy.yaml
```

---

### 주의 사항

* mTLS 설정 이전에 Matching Deployment를 적용하면 **인증서 참조 오류 발생**
* 인증서 재생성이 필요한 경우, 기존 Secret 삭제 후 스크립트 재실행 권장
* Game ↔ Matching 통신 포트 및 SAN 설정은 `setup-mtls.sh` 기준으로 유지

---


## ✅ 운영 원칙 요약

* CloudFormation → **공통 인프라**
* Terraform → **EKS / 네트워크**
* Kubernetes → **서비스 리소스**
* DR 리전은 **평상시 Core만 유지**
* 모든 삭제는 **K8S → Terraform 순서**

---




