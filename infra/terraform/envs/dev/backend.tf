# Terraform state for the dev environment is stored in S3 and protected by a
# DynamoDB lock table. The backend resources are bootstrapped before this
# backend is initialized.

terraform {
  backend "s3" {
    bucket         = "cpemon-terraform-state-dev-701573843911"
    key            = "cpemon/dev/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "cpemon-terraform-locks-dev"
    encrypt        = true
    profile        = "cpemon-terraform"
  }
}
