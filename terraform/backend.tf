terraform {
  backend "s3" {
    bucket         = "nainika-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# # 1. Create S3 bucket with proper configuration
# aws s3api create-bucket --bucket nainika-terraform-state \
#   --region ap-south-1 \
#   --create-bucket-configuration LocationConstraint=ap-south-1

# # 2. Enable versioning
# aws s3api put-bucket-versioning --bucket nainika-terraform-state \
#   --versioning-configuration Status=Enabled

# # 3. Enable encryption
# aws s3api put-bucket-encryption --bucket nainika-terraform-state \
#   --server-side-encryption-configuration '{
#     "Rules": [{
#       "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}
#     }]
#   }'

# # 4. Create DynamoDB table
# aws dynamodb create-table --table-name terraform-state-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region ap-south-1