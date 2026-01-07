
data "aws_iam_policy_document" "xray_daemon_assume" {
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
      values   = ["system:serviceaccount:aws-xray:xray-daemon"]
    }
  }
}

resource "aws_iam_role" "xray_daemon_role" {
  name               = "${module.eks.cluster_name}-xray-daemon-role"
  assume_role_policy = data.aws_iam_policy_document.xray_daemon_assume.json
}

resource "aws_iam_role_policy_attachment" "xray_daemon_attach" {
  role       = aws_iam_role.xray_daemon_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}
