variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "services" {
  description = "List of service names to create ECR repositories for"
  type        = list(string)
  default     = ["file-downloader", "rss-feed"]
}

variable "image_retention_count" {
  description = "Number of images to retain per repository (older images are expired)"
  type        = number
  default     = 10
}
