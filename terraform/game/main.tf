data "aws_vpc" "game" {
  filter {
    name   = "tag:Name"
    values = [var.game_vpc_name]
  }
}

data "aws_subnet" "game_private_a" {
  filter {
    name   = "tag:Name"
    values = [var.game_private_subnet_a_name]
  }
}

data "aws_subnet" "game_private_b" {
  filter {
    name   = "tag:Name"
    values = [var.game_private_subnet_b_name]
  }
}

data "aws_subnet" "game_public_a" {
  filter {
    name   = "tag:Name"
    values = [var.game_public_subnet_a_name]
  }
}

data "aws_subnet" "game_public_b" {
  filter {
    name   = "tag:Name"
    values = [var.game_public_subnet_b_name]
  }
}

module "eks" {
  source = "../modules/eks"

  cluster_name = var.cluster_name
  vpc_id       = data.aws_vpc.game.id
  subnet_ids   = [
    data.aws_subnet.game_private_a.id,
    data.aws_subnet.game_private_b.id
  ]

  node_group_name = "game-node-group-v2"
  instance_types  = ["t3.large"]
  disk_size       = 60
  desired_size    = 4
  max_size        = 5
  min_size        = 1

  # Public Node Group for Agones
  create_public_node_group = true
  public_node_group_name   = "game-public-node-group"
  public_subnet_ids = [
    data.aws_subnet.game_public_a.id,
    data.aws_subnet.game_public_b.id
  ]
  public_instance_types = ["t3.large"]
  public_desired_size   = 4
  public_max_size       = 5
  public_min_size       = 1
}