terraform {
  backend "s3" {
    bucket         = "nainika-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
    # Note: Ensure the S3 bucket and DynamoDB table exist before 