#!/bin/bash

# Deploy Monitoring Stack (Prometheus & Grafana) to EKS
# This script deploys the pre-configured monitoring stack with dashboards

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="monitoring"
RELEASE_NAME="prometheus"
VALUES_FILE="k8s/monitoring/prometheus-values.yaml"
HELM_REPO="prometheus-community"
HELM_CHART="kube-prometheus-stack"
HELM_REPO_URL="https://prometheus-community.github.io/helm-charts"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if kubectl is configured
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "kubectl is not configured or cluster is not accessible"
        print_error "Please run: aws eks update-kubeconfig --region ap-south-1 --name <cluster-name>"
        exit 1
    fi

    # Check if helm is installed
    if ! command -v helm >/dev/null 2>&1; then
        print_error "Helm is not installed. Please install Helm 3.x"
        exit 1
    fi

    # Check if values file exists
    if [ ! -f "$VALUES_FILE" ]; then
        print_error "Values file not found: $VALUES_FILE"
        exit 1
    fi

    print_status "Prerequisites check passed"
}

# Function to setup Helm repo
setup_helm_repo() {
    print_status "Setting up Helm repository..."

    # Add or update the Helm repository
    if helm repo list | grep -q "$HELM_REPO"; then
        helm repo update "$HELM_REPO"
    else
        helm repo add "$HELM_REPO" "$HELM_REPO_URL"
    fi

    print_status "Helm repository ready"
}

# Function to create namespace if it doesn't exist
create_namespace() {
    print_status "Ensuring namespace exists..."

    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        kubectl create namespace "$NAMESPACE"
        print_status "Created namespace: $NAMESPACE"
    else
        print_status "Namespace already exists: $NAMESPACE"
    fi
}

# Function to deploy monitoring stack
deploy_monitoring() {
    print_status "Deploying monitoring stack..."

    # Check if release already exists
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_warning "Release $RELEASE_NAME already exists. Upgrading..."
        helm upgrade "$RELEASE_NAME" "$HELM_REPO/$HELM_CHART" \
            -f "$VALUES_FILE" \
            -n "$NAMESPACE" \
            --wait \
            --timeout 600s
    else
        print_status "Installing monitoring stack..."
        helm install "$RELEASE_NAME" "$HELM_REPO/$HELM_CHART" \
            -f "$VALUES_FILE" \
            -n "$NAMESPACE" \
            --create-namespace \
            --wait \
            --timeout 600s
    fi

    print_status "Monitoring stack deployment completed"
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."

    # Wait for pods to be ready
    print_status "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance="$RELEASE_NAME" -n "$NAMESPACE" --timeout=300s

    # Check pod status
    print_status "Pod status:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"

    # Check services
    print_status "Service status:"
    kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"

    # Get Grafana admin password if needed
    if kubectl get secret -n "$NAMESPACE" "$RELEASE_NAME-grafana" >/dev/null 2>&1; then
        GRAFANA_PASSWORD=$(kubectl get secret -n "$NAMESPACE" "$RELEASE_NAME-grafana" -o jsonpath="{.data.admin-password}" | base64 --decode)
        print_status "Grafana admin password: $GRAFANA_PASSWORD"
        print_status "Grafana URL: https://grafana.nainika.store"
    fi

    print_status "Verification completed"
}

# Function to display access information
display_access_info() {
    echo ""
    print_status "=== Monitoring Stack Access Information ==="
    echo "Grafana Dashboard: https://grafana.nainika.store"
    echo "Username: admin"
    echo "Password: (Check above or use GRAFANA_ADMIN_PASSWORD env var)"
    echo ""
    echo "Prometheus (internal): kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME-prometheus 9090:9090"
    echo "AlertManager (internal): kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME-alertmanager 9093:9093"
    echo ""
    print_status "Pre-configured dashboards are automatically imported:"
    echo "- Kubernetes Cluster Monitoring"
    echo "- Kubernetes Pods Monitoring"
    echo "- Node Exporter Full"
    echo "- NGINX Ingress Controller"
    echo "- Prometheus 2.0 Overview"
}

# Main execution
main() {
    echo "========================================"
    echo "Deploying Prometheus & Grafana to EKS"
    echo "========================================"

    check_prerequisites
    setup_helm_repo
    create_namespace
    deploy_monitoring
    verify_deployment
    display_access_info

    print_status "🎉 Monitoring stack deployment successful!"
}

# Run main function
main "$@"