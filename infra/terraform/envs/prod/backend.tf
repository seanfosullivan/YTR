terraform {
  backend "s3" {
    bucket         = "ytr-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ytr-terraform-locks"
    encrypt        = true
  }
}
