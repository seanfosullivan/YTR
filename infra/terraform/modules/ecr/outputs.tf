output "repository_urls" {
  description = "Map of service name to ECR repository URL"
  value       = { for k, v in aws_ecr_repository.service : k => v.repository_url }
}

output "registry_id" {
  description = "ECR registry ID (AWS account ID)"
  value       = length(aws_ecr_repository.service) > 0 ? values(aws_ecr_repository.service)[0].registry_id : ""
}
