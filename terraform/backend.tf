# Uncomment after creating S3 bucket and DynamoDB table for state locking
# terraform {
#   backend "s3" {
#     bucket         = "nainika-terraform-state"
#     key            = "eks/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

# Initial setup (run these AWS CLI commands first):
# aws s3api create-bucket --bucket nainika-terraform-state --region ap-south-1
# aws s3api put-bucket-versioning --bucket nainika-terraform-state --versioning-configuration Status=Enabled
# aws dynamodb create-table --table-name terraform-state-lock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region ap-south-1