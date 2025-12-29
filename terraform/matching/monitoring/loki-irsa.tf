data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

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
  }
}

resource "aws_iam_role" "loki" {
  name               = "${var.cluster_name}-loki-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.loki_assume.json
}

resource "aws_iam_role_policy" "loki" {
  role = aws_iam_role.loki.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::t3-wagu-loki-logs",
          "arn:aws:s3:::t3-wagu-loki-logs/*"
        ]
      }
    ]
  })
}
