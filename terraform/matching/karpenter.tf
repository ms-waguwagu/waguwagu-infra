# Karpenter (Controller + IRSA) - On-Demand only

variable "karpenter_version" {
  type    = string
  default = "1.8.3" # Karpenter 공식 getting-started 예시 버전 
}

locals {
  karpenter_namespace = "kube-system"
  karpenter_sa        = "karpenter"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# (A) Karpenter Node Role 
resource "aws_iam_role" "karpenter_node_role" {
  name = "KarpenterNodeRole-${module.eks.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}
resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Karpenter Controller IRSA Role

data "aws_iam_policy_document" "karpenter_controller_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${local.karpenter_namespace}:${local.karpenter_sa}"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller_role" {
  name               = "${module.eks.cluster_name}-karpenter"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume.json
}

# - iam:PassRole이 있어야 Node Role을 EC2에 붙일 수 있음 
# - clusterEndpoint는 설정하면 되지만, 미설정 시 DescribeCluster로 자동 탐지 

data "aws_iam_policy_document" "karpenter_controller_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",

      "ec2:RunInstances",
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:DeleteLaunchTemplate",
      "ec2:TerminateInstances",
      "ec2:CreateTags",

      "ec2:DescribeInstances",
      "ec2:DescribeImages",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeSpotPriceHistory",

      "ssm:GetParameter",
      "pricing:GetProducts",

      "iam:CreateInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:ListInstanceProfiles",
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.karpenter_node_role.arn]
  }
}

resource "aws_iam_policy" "karpenter_controller_policy" {
  name   = "KarpenterControllerPolicy-${module.eks.cluster_name}"
  policy = data.aws_iam_policy_document.karpenter_controller_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_attach" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}


#  K8s ServiceAccount (IRSA role-arn annotation)
resource "kubernetes_service_account" "karpenter_sa" {
  metadata {
    name      = local.karpenter_sa
    namespace = local.karpenter_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_controller_role.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_controller_attach
  ]
}

# Helm Install Karpenter Controller
# - settings.clusterName은 필수 
# - On-Demand only라서 interruptionQueue(SQS)는 설정 안 함

resource "helm_release" "karpenter" {
  name      = "karpenter"
  namespace = local.karpenter_namespace

  chart   = "oci://public.ecr.aws/karpenter/karpenter"
  version = var.karpenter_version

  wait            = true
  wait_for_jobs   = true
  timeout         = 600
  atomic          = true
  cleanup_on_fail = true

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }

  # 생략 시 DescribeCluster로 endpoint를 자동 탐지
  set {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  # 온디맨드-only: interruptionQueue 미설정 (SQS 안 만드니까)
  # set { name = "settings.interruptionQueue" value = local.cluster_name }

  set {
    name  = "controller.resources.requests.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.karpenter_sa.metadata[0].name
  }

  depends_on = [
    kubernetes_service_account.karpenter_sa
  ]
}
