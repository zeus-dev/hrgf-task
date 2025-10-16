#!/bin/bash

# AWS EKS Infrastructure - Backend Setup Script
# This script creates the S3 bucket and DynamoDB table for Terraform remote state

set -e

# Configuration
AWS_REGION="${AWS_REGION:-ap-south-1}"
S3_BUCKET="${S3_BUCKET:-nainika-terraform-state}"
DYNAMODB_TABLE="${DYNAMODB_TABLE:-terraform-state-lock}"

echo "=========================================="
echo "AWS EKS Infrastructure - Backend Setup"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  AWS Region:      $AWS_REGION"
echo "  S3 Bucket:       $S3_BUCKET"
echo "  DynamoDB Table:  $DYNAMODB_TABLE"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS credentials are not configured properly."
    echo "Please run 'aws configure' to set up your credentials."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✓ AWS Account ID: $ACCOUNT_ID"
echo ""

# Create S3 bucket for Terraform state
echo "Creating S3 bucket for Terraform state..."
if aws s3 ls "s3://$S3_BUCKET" 2>/dev/null; then
    echo "✓ S3 bucket '$S3_BUCKET' already exists"
else
    if [ "$AWS_REGION" == "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$S3_BUCKET" \
            --region "$AWS_REGION"
    else
        aws s3api create-bucket \
            --bucket "$S3_BUCKET" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    echo "✓ S3 bucket '$S3_BUCKET' created successfully"
fi

# Enable versioning on the S3 bucket
echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "$S3_BUCKET" \
    --versioning-configuration Status=Enabled \
    --region "$AWS_REGION"
echo "✓ Versioning enabled on S3 bucket"

# Enable encryption on the S3 bucket
echo "Enabling encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket "$S3_BUCKET" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }' \
    --region "$AWS_REGION"
echo "✓ Encryption enabled on S3 bucket"

# Create DynamoDB table for state locking
echo "Creating DynamoDB table for state locking..."
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" &>/dev/null; then
    echo "✓ DynamoDB table '$DYNAMODB_TABLE' already exists"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" \
        --tags Key=Terraform,Value=true Key=Project,Value=nainika-store
    
    echo "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
    echo "✓ DynamoDB table '$DYNAMODB_TABLE' created successfully"
fi

echo ""
echo "=========================================="
echo "Backend Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Uncomment the backend configuration in terraform/backend.tf"
echo "2. Update the region in backend.tf to '$AWS_REGION'"
echo "3. Run 'terraform init' to initialize the backend"
echo "4. Run 'terraform plan' to verify the configuration"
echo "5. Run 'terraform apply' to provision the infrastructure"
echo ""
