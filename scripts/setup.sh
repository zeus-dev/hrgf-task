#!/bin/bash

# Nainika Store Infrastructure Setup Script
# This script automates the initial setup of the complete infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="ap-south-1"
CLUSTER_NAME="nasa-eks"
BUCKET_NAME="nainika-terraform-state"
DYNAMODB_TABLE="terraform-state-lock"

echo -e "${BLUE}🚀 Nainika Store Infrastructure Setup${NC}"
echo -e "${BLUE}=====================================\n${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed${NC}"
    exit 1
fi

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

# Check helm
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm is not installed${NC}"
    exit 1
fi

# Check terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites are installed${NC}\n"

# Verify AWS credentials
echo -e "${YELLOW}Verifying AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured properly${NC}"
    echo -e "${YELLOW}Please run: aws configure${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✅ AWS credentials verified (Account: $ACCOUNT_ID)${NC}\n"

# Step 1: Setup Terraform Backend
echo -e "${YELLOW}Step 1: Setting up Terraform backend...${NC}"

# Create S3 bucket
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  S3 bucket $BUCKET_NAME already exists${NC}"
else
    echo -e "${BLUE}Creating S3 bucket: $BUCKET_NAME${NC}"
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION"
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    echo -e "${GREEN}✅ S3 bucket created and versioning enabled${NC}"
fi

# Create DynamoDB table
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" &> /dev/null; then
    echo -e "${YELLOW}⚠️  DynamoDB table $DYNAMODB_TABLE already exists${NC}"
else
    echo -e "${BLUE}Creating DynamoDB table: $DYNAMODB_TABLE${NC}"
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION"
    
    echo -e "${GREEN}✅ DynamoDB table created${NC}"
fi

echo -e "${GREEN}✅ Terraform backend setup complete${NC}\n"

# Step 2: Initialize and Apply Terraform
echo -e "${YELLOW}Step 2: Deploying infrastructure with Terraform...${NC}"

cd terraform

# Check if backend is uncommented
if grep -q "^#.*backend \"s3\"" backend.tf; then
    echo -e "${YELLOW}⚠️  Terraform backend is commented out${NC}"
    echo -e "${BLUE}Uncommenting backend configuration...${NC}"
    
    # Uncomment the backend configuration
    sed -i.bak 's/^# terraform {/terraform {/' backend.tf
    sed -i.bak 's/^#   backend "s3" {/  backend "s3" {/' backend.tf
    sed -i.bak 's/^#     bucket/    bucket/' backend.tf
    sed -i.bak 's/^#     key/    key/' backend.tf
    sed -i.bak 's/^#     region/    region/' backend.tf
    sed -i.bak 's/^#     encrypt/    encrypt/' backend.tf
    sed -i.bak 's/^#     dynamodb_table/    dynamodb_table/' backend.tf
    sed -i.bak 's/^#   }/  }/' backend.tf
    sed -i.bak 's/^# }/}/' backend.tf
    
    echo -e "${GREEN}✅ Backend configuration uncommented${NC}"
fi

# Initialize Terraform
echo -e "${BLUE}Initializing Terraform...${NC}"
terraform init

# Validate configuration
echo -e "${BLUE}Validating Terraform configuration...${NC}"
terraform validate

# Plan infrastructure
echo -e "${BLUE}Planning infrastructure changes...${NC}"
terraform plan -out=tfplan

# Apply infrastructure
echo -e "${BLUE}Applying infrastructure changes...${NC}"
echo -e "${YELLOW}This may take 15-20 minutes...${NC}"
terraform apply tfplan

echo -e "${GREEN}✅ Infrastructure deployment complete${NC}\n"

# Step 3: Configure kubectl
echo -e "${YELLOW}Step 3: Configuring kubectl...${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
echo -e "${GREEN}✅ kubectl configured${NC}\n"

# Step 4: Install essential Kubernetes components
echo -e "${YELLOW}Step 4: Installing Kubernetes components...${NC}"

cd ../

# Add Helm repositories
echo -e "${BLUE}Adding Helm repositories...${NC}"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespaces
echo -e "${BLUE}Creating namespaces...${NC}"
kubectl apply -f k8s/namespaces/namespaces.yaml

# Install NGINX Ingress Controller
echo -e "${BLUE}Installing NGINX Ingress Controller...${NC}"
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --wait

# Install cert-manager
echo -e "${BLUE}Installing cert-manager...${NC}"
helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set installCRDs=true \
    --wait

# Install monitoring stack
echo -e "${BLUE}Installing Prometheus and Grafana...${NC}"
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    -f k8s/monitoring/prometheus-values.yaml \
    -n monitoring \
    --create-namespace \
    --wait

echo -e "${GREEN}✅ Essential components installed${NC}\n"

# Step 5: Get important information
echo -e "${YELLOW}Step 5: Gathering important information...${NC}"

# Get Load Balancer URL
echo -e "${BLUE}Getting NGINX Ingress Load Balancer URL...${NC}"
LB_HOSTNAME=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -n "$LB_HOSTNAME" ]; then
    echo -e "${GREEN}✅ Load Balancer URL: $LB_HOSTNAME${NC}"
else
    echo -e "${YELLOW}⚠️  Load Balancer is still provisioning. Check later with:${NC}"
    echo -e "${BLUE}kubectl get svc ingress-nginx-controller -n ingress-nginx${NC}"
fi

# Get Grafana password
echo -e "${BLUE}Getting Grafana admin password...${NC}"
GRAFANA_PASSWORD=$(kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode 2>/dev/null || echo "Password not available yet")
echo -e "${GREEN}✅ Grafana admin password: $GRAFANA_PASSWORD${NC}"

echo -e "\n${GREEN}🎉 Setup Complete!${NC}"
echo -e "${GREEN}==================${NC}\n"

echo -e "${YELLOW}Next Steps:${NC}"
echo -e "${BLUE}1. Configure your DNS (Cloudflare) to point to: $LB_HOSTNAME${NC}"
echo -e "${BLUE}2. Update k8s/tls/cloudflare-certificates.yaml with your Cloudflare API token${NC}"
echo -e "${BLUE}3. Apply TLS certificates: kubectl apply -f k8s/tls/cloudflare-certificates.yaml${NC}"
echo -e "${BLUE}4. Deploy your application using GitHub Actions or manually with Helm${NC}"
echo -e "${BLUE}5. Access Grafana at: https://grafana.nainika.store (after DNS setup)${NC}"

echo -e "\n${YELLOW}Useful Commands:${NC}"
echo -e "${BLUE}• Check cluster status: kubectl get nodes${NC}"
echo -e "${BLUE}• View all pods: kubectl get pods -A${NC}"
echo -e "${BLUE}• Check ingress: kubectl get ingress -A${NC}"
echo -e "${BLUE}• Monitor deployments: kubectl get deployments -A${NC}"

echo -e "\n${GREEN}Happy deploying! 🚀${NC}"