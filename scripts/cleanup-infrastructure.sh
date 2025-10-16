#!/bin/bash

# AWS EKS Infrastructure - Cleanup Script
# This script destroys all infrastructure components safely

set -e

# Configuration
AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-nasa-eks}"

echo "=========================================="
echo "AWS EKS Infrastructure - Cleanup"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This will destroy all infrastructure!"
echo ""
echo "Configuration:"
echo "  AWS Region:      $AWS_REGION"
echo "  Cluster Name:    $CLUSTER_NAME"
echo ""

# Confirmation
read -p "Are you sure you want to destroy all infrastructure? Type 'yes' to confirm: " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "Starting cleanup process..."

# Check if kubectl is available and cluster is accessible
if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
    echo ""
    echo "=========================================="
    echo "Step 1: Clean up Kubernetes Resources"
    echo "=========================================="
    
    # Delete Helm releases
    echo "Deleting Helm releases..."
    
    # Delete application deployments
    helm uninstall frontend-app-prod -n prod || true
    helm uninstall frontend-app-stage -n stage || true
    
    # Delete monitoring stack
    helm uninstall kube-prometheus-stack -n monitoring || true
    
    # Delete NGINX Ingress Controller
    helm uninstall ingress-nginx -n ingress-nginx || true
    
    echo "Waiting for LoadBalancer to be deleted..."
    sleep 30
    
    # Delete namespaces (this will also delete all resources in them)
    echo "Deleting namespaces..."
    kubectl delete namespace prod --ignore-not-found=true
    kubectl delete namespace stage --ignore-not-found=true
    kubectl delete namespace monitoring --ignore-not-found=true
    kubectl delete namespace ingress-nginx --ignore-not-found=true
    
    # Wait for namespaces to be fully deleted
    echo "Waiting for namespaces to be deleted..."
    kubectl wait --for=delete namespace/prod --timeout=300s || true
    kubectl wait --for=delete namespace/stage --timeout=300s || true
    kubectl wait --for=delete namespace/monitoring --timeout=300s || true
    kubectl wait --for=delete namespace/ingress-nginx --timeout=300s || true
else
    echo "Skipping Kubernetes cleanup (cluster not accessible)"
fi

echo ""
echo "=========================================="
echo "Step 2: Destroy Terraform Infrastructure"
echo "=========================================="

cd terraform

# Terraform destroy
echo "Running terraform destroy..."
terraform destroy -auto-approve

cd ..

echo ""
echo "=========================================="
echo "Step 3: Clean up Backend (Optional)"
echo "=========================================="

read -p "Do you want to delete the Terraform backend (S3 bucket and DynamoDB table)? (yes/no): " delete_backend
if [ "$delete_backend" == "yes" ]; then
    S3_BUCKET="${S3_BUCKET:-nainika-terraform-state}"
    DYNAMODB_TABLE="${DYNAMODB_TABLE:-terraform-state-lock}"
    
    # Delete S3 bucket
    echo "Deleting S3 bucket..."
    aws s3 rb "s3://$S3_BUCKET" --force --region "$AWS_REGION" || true
    
    # Delete DynamoDB table
    echo "Deleting DynamoDB table..."
    aws dynamodb delete-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" || true
    
    echo "✓ Backend resources deleted"
fi

echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
echo "All infrastructure has been destroyed."
echo "Local Terraform state files are still present in the terraform directory."
echo ""
