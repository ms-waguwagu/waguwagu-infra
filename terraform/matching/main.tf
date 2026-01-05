data "aws_vpc" "matching" {
  filter {
    name   = "tag:Name"
    values = [var.matching_vpc_name]
  }
}

data "aws_subnet" "matching_private_a" {
  filter {
    name   = "tag:Name"
    values = [var.matching_private_subnet_a_name]
  }
}

data "aws_subnet" "matching_private_b" {
  filter {
    name   = "tag:Name"
    values = [var.matching_private_subnet_b_name]
  }
}

module "eks" {
  source = "../modules/eks"

  cluster_name = var.cluster_name

  vpc_id = data.aws_vpc.matching.id

  subnet_ids = [
    data.aws_subnet.matching_private_a.id,
    data.aws_subnet.matching_private_b.id
  ]

  node_group_name = "matching-node-group"

  instance_types = ["t3.medium"]

  desired_size = 4
  min_size     = 1
  max_size     = 5
}
