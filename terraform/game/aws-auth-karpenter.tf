data "aws_caller_identity" "this" {}

data "kubernetes_config_map_v1" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  depends_on = [module.eks]
}

locals {
  karpenter_role_arn = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/KarpenterNodeRole-${module.eks.cluster_name}"

  existing_map_roles = try(
    yamldecode(lookup(data.kubernetes_config_map_v1.aws_auth.data, "mapRoles", "[]")),
    []
  )

  has_karpenter = length([
    for r in local.existing_map_roles : r
    if try(r.rolearn, "") == local.karpenter_role_arn
  ]) > 0

  karpenter_role = {
    rolearn  = local.karpenter_role_arn
    username = "system:node:{{EC2PrivateDNSName}}"
    groups   = ["system:bootstrappers", "system:nodes"]
  }

  merged_roles = local.has_karpenter ? local.existing_map_roles : concat(local.existing_map_roles, [local.karpenter_role])
}

resource "kubernetes_config_map_v1_data" "aws_auth_maproles" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(local.merged_roles)
  }

  field_manager = "Terraform"
  force         = true

  depends_on = [module.eks]
}