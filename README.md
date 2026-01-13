

---

# waguwagu-infra 배포 가이드

**(Terraform + CloudFormation 기반 인프라 운영 문서)**

이 문서는 **WAGUWAGU 서비스 인프라의 배포, 운영, 삭제 절차**를 정리합니다.
인프라는 **AWS CloudFormation + Terraform + Kubernetes(EKS)** 기반으로 구성되어 있습니다.

* **메인 리전**: 서울 (`ap-northeast-2`)
* **DR 리전**: 도쿄 (`ap-northeast-1`)

---

## 목차

1. [📂 프로젝트 구조](#-프로젝트-구조-project-structure)

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
10. [mTLS 설정 및 Matching 서버 배포](#10-mtls-설정-및-matching-서버-배포)

---

## 📂 프로젝트 구조 (Project Structure)

```text
waguwagu-infra/
├── cloudformation/           # 기초 인프라 (VPC, IAM, 공통 리소스)
│   ├── seoul/                # 메인 리전 (서울) 인프라 구성 템플릿
│   ├── tokyo/                # DR 리전 (도쿄) 인프라 구성 템플릿
│   └── deploy/               # 초기 인프라 일괄 배포 스크립트
│
├── terraform/                # EKS 클러스터 및 플랫폼 리소스 관리
│   ├── game/                 # Game EKS 클러스터 및 Agones 컨트롤러 설정
│   ├── matching/             # Matching EKS 클러스터 및 애플리케이션 기초 설정
│   ├── modules/              # VPC, EKS, SG 등 재사용 가능한 인프라 모듈
│   └── scripts/              # 모니터링 설치 및 리소스 삭제 자동화 스크립트
│
└── k8s/                      # Kubernetes 서비스 리소스 및 워크로드
    ├── agones/               # Agones Fleet 설정 및 mTLS 인증서 통신 보안
    ├── matching/             # 매칭 서버 배포 매니페스트 (Deployment, HPA, Ingress)
    ├── karpenter/            # 효율적인 노드 확장을 위한 NodePool/NodeClass 설정
    └── scripts/              # mTLS 연동 및 통합 서비스 배포 메인 스크립트
```

### 계층별 역할 요약
1. **CloudFormation (Foundations)**: 인프라의 가장 바닥인 네트워크와 권한(IAM)을 구축합니다.
2. **Terraform (Provisioning)**: 프로비저닝 단계로 EKS 클러스터와 필요한 관리 도구들을 설치합니다.
3. **Kubernetes (Services)**: 실제 서비스가 돌아가는 단계로 애플리케이션과 세부 설정을 관리합니다.

---

# CloudFormation

## 1. 사전 준비

### AWS CLI 설정 (서울 리전 기준)

```bash
aws configure
# Default region: ap-northeast-2
# Output format: json
```

---

## 2. CloudFormation 배포 위치

모든 CloudFormation 스크립트는 아래 디렉토리에서 실행합니다.

```bash
waguwagu-infra/cloudformation/deploy
```

---

## 3. CloudFormation 전체 자동 배포 (서울 리전)

서울 리전의 **공통 인프라(VPC, IAM, 기본 리소스)** 를 일괄 배포합니다.

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

> ⚠️ Ingress 생성 후 ALB DNS가 준비된 상태여야 합니다.

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

# Terraform / Kubernetes

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

> ⚠️ EKS가 없으면 helm/kubernetes 리소스가 실패합니다.

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
kubectl config use-context arn:aws:eks:ap-northeast-2:<AWS_ACCOUNT_ID>:cluster/T3-Wagu-Matching-EKS
kubectl config use-context arn:aws:eks:ap-northeast-2:<AWS_ACCOUNT_ID>:cluster/T3-Wagu-Game-EKS
```

---

---

## 6. Kubernetes 리소스 배포 (권장)

### Matching

```bash
cd waguwagu-infra
./k8s/scripts/deploy-matching.sh
```
> mTLS 설정, Karpenter 설정, 서비스 배포가 일괄 진행됩니다.

### Game

```bash
cd waguwagu-infra
./k8s/scripts/deploy-game.sh
```
> Agones 설정, 도메인 인증, Karpenter 설정이 일괄 진행됩니다.

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
# waguwagu-infra 루트 디렉토리에서 실행
./terraform/scripts/destroy-k8s.sh
```

---

## 9. Terraform 리소스 삭제 (자동화)

```bash
# waguwagu-infra 루트 디렉토리에서 실행
./terraform/scripts/destroy-all.sh
```

---


## 10. mTLS 설정 및 Matching 서버 배포

Matching 서버는 Game 서버로부터 할당 정보를 안전하게 받기 위해 **mTLS**를 사용합니다. 
<br>이 모든 과정은 자동화 스크립트에 통합되어 있습니다.

---

### 통합 배포 스크립트 실행

별도의 인증서 추출 과정 없이, 아래 스크립트 하나로 **mTLS 설정 + Allocator 엔드포인트 갱신 + 서버 배포**가 일괄 수행됩니다.

```bash
cd waguwagu-infra
./k8s/scripts/deploy-matching.sh
```

**스크립트 내부 동작:**
1. **Allocator 조회**: Game 클러스터에서 `agones-allocator`의 접속 주소를 자동으로 가져옴.
2. **mTLS 자동 설정**: `setup-mtls.sh`를 호출하여 인증서(CA, Client) 추출 및 Matching 클러스터 적용.
3. **환경 변수 갱신**: `matching-deploy.yaml`의 엔드포인트를 최신화.
4. **최종 배포**: 모든 설정이 완료된 후 Matching 서버를 클러스터에 배포.

---

### 주의 사항

* **도메인 확인**: 게임 서버 접속은 공인 인증서(`wss://*.game.waguwagu.cloud`)를 사용하며, 서버 간 통신은 mTLS를 사용합니다.

---


## 운영 원칙 요약

* CloudFormation → **공통 인프라**
* Terraform → **EKS / 네트워크**
* Kubernetes → **서비스 리소스**
* DR 리전은 **평상시 Core만 유지**
* 모든 삭제는 **K8S → Terraform 순서**

---




