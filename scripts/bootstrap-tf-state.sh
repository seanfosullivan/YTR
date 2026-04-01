#!/bin/bash
# One-time bootstrap: create S3 buckets + DynamoDB table for Terraform remote state.
# Run this once before the first `terraform init` in any environment.
#
# Usage:
#   AWS_REGION=us-east-1 bash scripts/bootstrap-tf-state.sh
#
# Prerequisites:
#   - AWS CLI configured (aws configure, or AWS_PROFILE / AWS_ACCESS_KEY_ID env vars set)
#   - The AWS account must have permissions to create S3 buckets and DynamoDB tables

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
PROJECT="ytr"
LOCK_TABLE="${PROJECT}-terraform-locks"

echo "==> Bootstrapping Terraform state backend in region: ${REGION}"

for ENV in dev prod; do
  BUCKET="${PROJECT}-terraform-state-${ENV}"
  echo ""
  echo "--- S3 bucket: ${BUCKET} ---"

  # us-east-1 does not accept a LocationConstraint; all other regions require it
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}" \
      2>/dev/null || echo "  Bucket may already exist, continuing"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}" \
      2>/dev/null || echo "  Bucket may already exist, continuing"
  fi

  aws s3api put-bucket-versioning \
    --bucket "${BUCKET}" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "${BUCKET}" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

  aws s3api put-public-access-block \
    --bucket "${BUCKET}" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  echo "  Ready: s3://${BUCKET}"
done

echo ""
echo "--- DynamoDB table: ${LOCK_TABLE} ---"
aws dynamodb create-table \
  --table-name "${LOCK_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}" \
  2>/dev/null || echo "  Table may already exist, continuing"

echo "  Ready: ${LOCK_TABLE}"

echo ""
echo "==> Bootstrap complete. Next steps:"
echo ""
echo "    cd infra/terraform/envs/dev"
echo "    terraform init"
echo "    terraform plan"
echo ""
echo "    cd infra/terraform/envs/prod"
echo "    terraform init"
echo "    terraform plan"
