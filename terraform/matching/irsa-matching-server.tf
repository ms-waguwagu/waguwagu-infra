
data "aws_iam_policy_document" "matching_server_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:matching:matching-sa"]
    }
  }
}

resource "aws_iam_role" "matching_server_role" {
  name               = "${module.eks.cluster_name}-matching-server-role"
  assume_role_policy = data.aws_iam_policy_document.matching_server_assume.json
}

data "aws_iam_policy_document" "matching_sqs_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    # 실제 환경에서는 구체적인 ARN을 지정하는 것이 좋으나, 
    # 현재는 유연성을 위해 모든 SQS를 허용하거나 변수로 받습니다.
    resources = ["*"] 
  }
}

resource "aws_iam_policy" "matching_sqs_policy" {
  name   = "${module.eks.cluster_name}-sqs-policy"
  policy = data.aws_iam_policy_document.matching_sqs_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "matching_sqs_attach" {
  role       = aws_iam_role.matching_server_role.name
  policy_arn = aws_iam_policy.matching_sqs_policy.arn
}

resource "kubernetes_service_account" "matching_sa" {
  metadata {
    name      = "matching-sa"
    namespace = "matching"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.matching_server_role.arn
    }
  }
}