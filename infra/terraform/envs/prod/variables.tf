variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Project name, used in resource naming"
  type        = string
  default     = "ytr"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (different from dev to avoid overlap)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_min_size" {
  type    = number
  default = 2
}

variable "eks_node_max_size" {
  type    = number
  default = 3
}

variable "eks_node_desired_size" {
  type    = number
  default = 2
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}
