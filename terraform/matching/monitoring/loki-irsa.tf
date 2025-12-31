############################################
# EKS Cluster & OIDC Data
############################################

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

############################################
# Loki IRSA Assume Role Policy
############################################

data "aws_iam_policy_document" "loki_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(
        data.aws_eks_cluster.this.identity[0].oidc[0].issuer,
        "https://",
        ""
      )}:sub"
      values = ["system:serviceaccount:monitoring:loki"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(
        data.aws_eks_cluster.this.identity[0].oidc[0].issuer,
        "https://",
        ""
      )}:aud"
      values = ["sts.amazonaws.com"]
    }
  }
}

############################################
# Loki IRSA Role
############################################

resource "aws_iam_role" "loki" {
  name               = "${var.cluster_name}-loki-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.loki_assume.json
}

############################################
# Loki S3 Access Policy
############################################

resource "aws_iam_role_policy" "loki" {
  name = "${var.cluster_name}-loki-s3-policy"
  role = aws_iam_role.loki.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          data.aws_cloudformation_export.loki_bucket_arn.value,
          "${data.aws_cloudformation_export.loki_bucket_arn.value}/*"
        ]
      }
    ]
  })
}
