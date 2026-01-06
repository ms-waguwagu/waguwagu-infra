/* 

# EKS Managed NodeGroup 노드 Role 등록 (aws-auth 없이도 조인 가능하게)
resource "aws_eks_access_entry" "managed_nodes" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.eks.managed_node_role_arn

  type = "EC2_LINUX"

  user_name = "system:node:{{EC2PrivateDNSName}}"
  kubernetes_groups = [
    "system:bootstrappers",
    "system:nodes",
  ]
}

# Karpenter가 띄우는 노드 Role 등록
resource "aws_eks_access_entry" "karpenter_nodes" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.karpenter_node_role.arn

  type = "EC2_LINUX"

  user_name = "system:node:{{EC2PrivateDNSName}}"
  kubernetes_groups = [
    "system:bootstrappers",
    "system:nodes",
  ]

  depends_on = [aws_iam_role.karpenter_node_role]
}


*/