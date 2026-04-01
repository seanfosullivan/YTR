terraform {
  backend "s3" {
    bucket         = "ytr-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ytr-terraform-locks"
    encrypt        = true
  }
}
