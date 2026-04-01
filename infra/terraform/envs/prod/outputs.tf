output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "kubeconfig_command" {
  description = "Run this command to update your local kubeconfig"
  value       = module.eks.kubeconfig_command
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by service name"
  value       = module.ecr.repository_urls
}
