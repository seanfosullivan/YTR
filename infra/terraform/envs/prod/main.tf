terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = "${var.project}-${var.environment}"
}

module "network" {
  source = "../../modules/network"

  name               = local.name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  single_nat_gateway = false  # one NAT GW per AZ for high availability
}

module "eks" {
  source = "../../modules/eks"

  name               = local.name
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  cluster_version    = var.eks_cluster_version
  node_instance_type = var.eks_node_instance_type
  node_min_size      = var.eks_node_min_size
  node_max_size      = var.eks_node_max_size
  node_desired_size  = var.eks_node_desired_size

  # TODO: restrict to your VPN or office CIDR before going live, e.g. ["203.0.113.5/32"]
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  enable_cluster_logging               = true
}

module "ecr" {
  source = "../../modules/ecr"

  name        = local.name
  environment = var.environment
  services    = ["file-downloader", "rss-feed"]
}
