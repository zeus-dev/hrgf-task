#!/bin/bash

# AWS EKS Infrastructure - Complete Setup Script
# This script sets up the entire EKS infrastructure with all components

set -e

# Configuration
AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-nasa-eks}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin123!}"

echo "=========================================="
echo "AWS EKS Infrastructure - Complete Setup"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  AWS Region:      $AWS_REGION"
echo "  Cluster Name:    $CLUSTER_NAME"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    exit 1
fi
echo "✓ AWS CLI installed"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo "Error: Terraform is not installed"
    exit 1
fi
echo "✓ Terraform installed"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi
echo "✓ kubectl installed"

# Check Helm
if ! command -v helm &> /dev/null; then
    echo "Error: Helm is not installed"
    exit 1
fi
echo "✓ Helm installed"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS credentials are not configured"
    exit 1
fi
echo "✓ AWS credentials configured"

echo ""
echo "=========================================="
echo "Step 1: Setup Terraform Backend"
echo "=========================================="

# Run backend setup
bash scripts/setup-backend.sh

echo ""
echo "=========================================="
echo "Step 2: Initialize and Apply Terraform"
echo "=========================================="

cd terraform

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Validate configuration
echo "Validating Terraform configuration..."
terraform validate

# Format check
echo "Formatting Terraform files..."
terraform fmt -recursive

# Plan
echo "Creating Terraform plan..."
terraform plan -out=tfplan

# Apply
read -p "Do you want to apply the Terraform plan? (yes/no): " confirm
if [ "$confirm" == "yes" ]; then
    echo "Applying Terraform configuration..."
    terraform apply tfplan
    rm tfplan
else
    echo "Terraform apply skipped"
    exit 0
fi

cd ..

echo ""
echo "=========================================="
echo "Step 3: Configure kubectl"
echo "=========================================="

echo "Updating kubeconfig..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
echo "✓ kubeconfig updated"

# Verify cluster access
echo "Verifying cluster access..."
kubectl get nodes
kubectl get namespaces

echo ""
echo "=========================================="
echo "Step 4: Wait for Components to be Ready"
echo "=========================================="

echo "Waiting for NGINX Ingress Controller..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=600s || true

echo "Waiting for monitoring stack..."
kubectl wait --namespace monitoring \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=grafana \
    --timeout=600s || true

echo ""
echo "=========================================="
echo "Step 5: Get Service Information"
echo "=========================================="

# Get LoadBalancer DNS
echo "Getting LoadBalancer DNS..."
LB_DNS=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "Not ready yet")
echo "LoadBalancer DNS: $LB_DNS"

# Get Grafana password
echo "Getting Grafana admin password..."
GRAFANA_PWD=$(kubectl get secret --namespace monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "Grafana Admin Password: $GRAFANA_PWD"

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Important Information:"
echo "----------------------"
echo "1. LoadBalancer DNS: $LB_DNS"
echo "   - Configure this DNS in Cloudflare for your domains:"
echo "     * grafana.nainika.store"
echo "     * prod.nainika.store"
echo "     * stage.nainika.store"
echo ""
echo "2. Grafana Access:"
echo "   - URL: http://grafana.nainika.store (after DNS configuration)"
echo "   - Username: admin"
echo "   - Password: $GRAFANA_PWD"
echo ""
echo "3. Next Steps:"
echo "   - Configure Cloudflare DNS records"
echo "   - Deploy applications using GitHub Actions or Helm"
echo "   - Access monitoring dashboards in Grafana"
echo ""
echo "Useful Commands:"
echo "  kubectl get pods -A                    # View all pods"
echo "  kubectl get svc -A                     # View all services"
echo "  kubectl get ingress -A                 # View all ingress"
echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo ""
