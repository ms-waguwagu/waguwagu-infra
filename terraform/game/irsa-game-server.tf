
data "aws_iam_policy_document" "game_server_assume" {
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
      values   = ["system:serviceaccount:game:game-server-sa"]
    }
  }
}

resource "aws_iam_role" "game_server_role" {
  name               = "${module.eks.cluster_name}-game-server-role"
  assume_role_policy = data.aws_iam_policy_document.game_server_assume.json
}

data "aws_iam_policy_document" "game_sqs_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "game_sqs_policy" {
  name   = "${module.eks.cluster_name}-sqs-policy"
  policy = data.aws_iam_policy_document.game_sqs_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "game_sqs_attach" {
  role       = aws_iam_role.game_server_role.name
  policy_arn = aws_iam_policy.game_sqs_policy.arn
}

resource "kubernetes_service_account" "game_sa" {
  metadata {
    name      = "game-server-sa"
    namespace = "game"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.game_server_role.arn
    }
  }
}