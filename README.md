# waguwagu-infra 배포 가이드 (Terraform + CloudFormation)

이 문서는 waguwagu 인프라에서 **CloudFormation 및 Terraform 기반 리소스 배포 및 운영 절차**를 정리한다.  
서울(ap-northeast-2) 리전을 메인으로, 도쿄(ap-northeast-1) 리전을 DR로 사용한다.

## CloudFormation 목차

- [1. 사전 준비](#1-사전-준비)
- [2. CloudFormation 배포 기본 위치](#2-cloudformation-배포-기본-위치)
- [3. CloudFormation 전체 자동 배포 (서울 리전)](#3-cloudformation-전체-자동-배포-서울-리전)
- [4. CloudFront 배포](#4-cloudfront-배포)
- [5. CloudWatch 스택 배포](#5-cloudwatch-스택-배포)
- [6. CloudTrail 배포 (서울 리전)](#6-cloudtrail-배포-서울-리전)
- [7. DR (도쿄 리전) 운영 절차](#7-dr-도쿄-리전-운영-절차)


## Terraform 목차

- [0. 사전 준비](#0-사전-준비)
- [1. Terraform 초기화](#1-terraform-초기화)
- [2. EKS 클러스터 먼저 배포](#2-eks-클러스터-먼저-배포)
- [3. Terraform 전체 배포](#3-terraform-전체-배포)
- [4. kubectl 클러스터 확인 및 전환](#4-kubectl-클러스터-확인-및-전환)
- [5. Karpenter 설정 (Matching 클러스터)](#5-karpenter-설정-matching-클러스터)
- [6. Kubernetes 리소스 배포](#6-kubernetes-리소스-배포)
- [7. Kubernetes 리소스 삭제](#7-kubernetes-리소스-삭제)
- [8. Terraform 리소스 삭제](#8-terraform-리소스-삭제)

---
# CloudFormation
---

## 1. 사전 준비

### AWS IAM 유저 설정 (서울 리전 기준)
```bash
aws configure
# Access Key / Secret Key 입력
# Default region: ap-northeast-2
# Output format: json
```

## 2. CloudFormation 배포 기본 위치

모든 CloudFormation 스크립트는 아래 경로에서 실행한다.
```bash
waguwagu-infra/cloudformation/deploy
```

## 3. CloudFormation 전체 자동 배포 (서울 리전)

서울 리전의 기본 인프라 스택을 일괄 배포한다.
```bash
./deploy-all.sh
```

### 권장 배포 순서

1. `deploy-all.sh` 실행 → 공통 인프라 배포 완료
2. Terraform 실행 → EKS 클러스터 및 노드 그룹 생성
3. CloudWatch 배포 → ASG 이름 확인 후 `T3-Wagu-CloudWatch.yaml` 배포
4. CloudFront 배포 → Ingress 생성 및 ALB DNS 확인 후 `deploy-cloudfront.sh` 실행

## 4. CloudFront 배포

### 실행 위치
```bash
waguwagu-infra/cloudformation/deploy
```

### CloudFront 자동 배포 스크립트

**서울 리전**
```bash
./deploy-cloudfront.sh
```

**DR 도쿄 리전**
```bash
./deploy-cloudfront.sh tokyo
```

## 5. CloudWatch 스택 배포

### 5-1. 서울 리전

**AutoScaling Group 이름 확인**
```bash
aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[].AutoScalingGroupName" \
  --output table \
  --region ap-northeast-2
```

예시:
```
eks-game-node-group-v2-xxxxxxxx
eks-matching-node-group-xxxxxxxx
```

**CloudWatch 스택 배포**
```bash
aws cloudformation deploy \
  --stack-name T3-Wagu-CloudWatch \
  --template-file T3-Wagu-Cloudwatch.yaml \
  --parameter-overrides \
    GameNodeASG=<GAME_NODE_ASG_NAME> \
    MatchingNodeASG=<MATCHING_NODE_ASG_NAME> \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-2
```

### 5-2. 도쿄 리전 (DR)

**AutoScaling Group 이름 확인**
```bash
aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[].AutoScalingGroupName" \
  --output table \
  --region ap-northeast-1
```

**CloudWatch DR 스택 배포**
```bash
aws cloudformation deploy \
  --stack-name T3-Wagu-CloudWatch-DR \
  --template-file T3-Wagu-CloudWatch-DR.yaml \
  --parameter-overrides \
    GameNodeASG=<GAME_NODE_ASG_NAME> \
    MatchingNodeASG=<MATCHING_NODE_ASG_NAME> \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

## 6. CloudTrail 배포 (서울 리전)

CloudTrail은 인프라 변경 및 DR 이벤트 감지를 위해 항상 활성화한다.
```bash
aws cloudformation deploy \
  --stack-name T3-Wagu-Cloudtrail \
  --template-file T3-Wagu-Cloudtrail.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-2 \
  --parameter-overrides AlertEmail=<ALERT_EMAIL>
```

### CloudTrail 오류 발생 시 로그 확인
```bash
aws cloudformation describe-stack-events \
  --stack-name T3-Wagu-Cloudtrail \
  --region ap-northeast-2
```

## 7. DR (도쿄 리전) 운영 절차

### 실행 위치
```bash
waguwagu-infra/cloudformation/deploy
```

### 항상 실행해야 하는 스크립트

DR 리전의 기본 인프라 코어 리소스를 배포한다.
```bash
./deploy-dr-core.sh
```

**CloudWatch (DR)**
```bash
aws cloudformation deploy \
  --stack-name T3-Wagu-CloudWatch-DR \
  --template-file T3-Wagu-CloudWatch-DR.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

### 장애 발생 시에만 실행하는 스크립트

서비스 레벨 리소스를 DR 리전에 배포한다.
```bash
./deploy-dr-services.sh
```

**DR 클러스터 생성 후 CloudFront (도쿄 리전)**

DR 게임/매칭 클러스터 생성이 완료된 이후 실행한다.
```bash
./deploy-cloudfront.sh tokyo
```

---
# Terraform
## 0. 사전 준비

### 작업 위치

각 클러스터별로 별도 디렉토리에서 작업해야 한다.
```bash
# Matching 클러스터
cd waguwagu-infra/terraform/matching

# Game 클러스터
cd waguwagu-infra/terraform/game
```

### 리전 설정

- **서울 리전 작업**: 기본 AWS 프로필 사용
- **도쿄 리전 작업**: AWS 계정 설정에서 도쿄 리전으로 변경하거나 DR 전용 프로필 생성

---

## 1. Terraform 초기화
```bash
terraform init
# Terraform 초기화
# init을 하지 않으면 plan/apply를 실행할 수 없음
```

---

## 2. EKS 클러스터 먼저 배포

EKS 클러스터/노드그룹을 먼저 설치한다. helm/kubernetes가 먼저 실행되면 오류가 발생할 수 있기 때문이다.

### 서울 리전
```bash
terraform apply \
  -target="module.eks" \
  -var-file=terraform.seoul.tfvars \
  -auto-approve
```

### 도쿄 리전 (DR)
```bash
terraform apply \
  -target="module.eks" \
  -var-file=terraform.tokyo.tfvars \
  -auto-approve
```

---


## 3. Terraform 전체 배포

### 서울 리전
```bash
terraform apply \
  -var-file=terraform.seoul.tfvars \
  -auto-approve
```

### 도쿄 리전 (DR)
```bash
terraform apply \
  -var-file=terraform.tokyo.tfvars \
  -auto-approve
```

---

## 4. kubectl 클러스터 확인 및 전환

### 현재 클러스터 확인
```bash
kubectl config current-context
kubectl get nodes
```

### 클러스터 전환
```bash
# Matching 클러스터로 전환
kubectl config use-context arn:aws:eks:ap-northeast-2:061039804626:cluster/T3-Wagu-Matching-EKS

# Game 클러스터로 전환
kubectl config use-context arn:aws:eks:ap-northeast-2:061039804626:cluster/T3-Wagu-Game-EKS
```

---

## 5. Karpenter 설정 (Matching 클러스터)

**중요**: Matching 클러스터 생성 후 Karpenter 규칙을 먼저 적용해야 한다.
```bash
cd waguwagu-infra/k8s/karpenter/matching

kubectl apply -f matching-nodeclass.yaml
kubectl apply -f matching-nodepool.yaml
kubectl get ec2nodeclass,nodepool
```

---

## 6. Kubernetes 리소스 배포
클러스터의 모든 Kubernetes 리소스는  
**전용 배포 스크립트를 통해 순서대로 자동 적용**한다.

### 6-1. Matching 클러스터 배포

### 실행 방법

```bash
cd waguwagu-infra
./scripts/deploy-matching.sh
```

---

### 6-2. Game 클러스터 배포

### 실행 방법

```bash
cd waguwagu-infra
./scripts/deploy-game.sh
```

---

## 7. Kubernetes 리소스 삭제

### 7-1. Matching 클러스터 삭제
```bash
cd waguwagu-infra/k8s/matching

# 역순으로 삭제
kubectl delete -f matching-hpa.yaml
kubectl delete -f matching-ingress.yaml
kubectl delete -f matching-deploy.yaml
kubectl delete -f matching-service.yaml
kubectl delete -f matching-externalsecret.yaml
kubectl delete -f matching-namespace.yaml

# 확인
kubectl get all -n matching
```

### 7-2. Game 클러스터 삭제
```bash
cd waguwagu-infra/k8s/game/agones

kubectl delete -f agones-fleet.yaml
helm uninstall agones -n agones-system
kubectl delete -f agones-externalsecret.yaml

# 확인
kubectl get all -n game
```

---

## 8. Terraform 리소스 삭제


### 서울 리전 삭제
```bash
# Matching 클러스터
cd waguwagu-infra/terraform/matching
terraform destroy -var-file=terraform.seoul.tfvars -auto-approve

# Game 클러스터
cd waguwagu-infra/terraform/game
terraform destroy -var-file=terraform.seoul.tfvars -auto-approve
```

### 도쿄 리전 삭제
```bash
# Matching 클러스터
cd waguwagu-infra/terraform/matching
terraform destroy -var-file=terraform.tokyo.tfvars -auto-approve

# Game 클러스터
cd waguwagu-infra/terraform/game
terraform destroy -var-file=terraform.tokyo.tfvars -auto-approve
```

---

