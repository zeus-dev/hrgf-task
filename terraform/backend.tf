# Terraform Backend Configuration
# 
# ⚠️  IMPORTANT: Before uncommenting this block:
# 1. Run: ./scripts/setup-backend.sh
# 2. Ensure the S3 bucket and DynamoDB table are created
# 3. Update the region if different from ap-south-1
# 
# After uncommenting, run: terraform init -migrate-state

terraform {
  backend "s3" {
    bucket         = "nainika-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
