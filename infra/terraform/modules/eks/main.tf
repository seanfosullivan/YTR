terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  cluster_name = "${var.name}-cluster"
}

data "aws_caller_identity" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Allow kubectl from the internet. Restrict access_cidrs to your IP or VPN CIDR
  # for production (e.g. ["203.0.113.0/32"]).
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Control-plane audit logging (opt-in; adds CloudWatch costs)
  cluster_enabled_log_types = var.enable_cluster_logging ? ["api", "audit", "authenticator", "controllerManager", "scheduler"] : []

  # Enable IAM Roles for Service Accounts (IRSA) for fine-grained pod-level IAM
  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      ami_type = "AL2023_x86_64_STANDARD"

      # SSM access for debugging nodes without SSH
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      tags = {
        Name        = "${local.cluster_name}-node"
        Environment = var.environment
      }
    }
  }

  # EKS add-ons. aws-ebs-csi-driver is required for PersistentVolumes (Prometheus storage).
  cluster_addons = {
    coredns            = { most_recent = true }
    kube-proxy         = { most_recent = true }
    vpc-cni            = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
  }

  tags = {
    Environment = var.environment
  }
}

# Scoped ECR read policy — nodes can only pull from this account's ytr/* repos
resource "aws_iam_policy" "ecr_pull_ytr" {
  name        = "${local.cluster_name}-ecr-pull-ytr"
  description = "Allow EKS nodes to pull images from ytr ECR repositories only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
        ]
        Resource = "arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/ytr-*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_pull_ytr" {
  role       = module.eks.eks_managed_node_groups["default"].iam_role_name
  policy_arn = aws_iam_policy.ecr_pull_ytr.arn
}
