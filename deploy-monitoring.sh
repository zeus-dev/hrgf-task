#!/bin/bash

# Deploy Monitoring Stack (Prometheus & Grafana) to EKS
# This script deploys the pre-configured monitoring stack with dashboards

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Enable debug mode if DEBUG=1
if [ "${DEBUG:-0}" = "1" ]; then
    set -x  # Print commands as they execute
    echo -e "${BLUE}[DEBUG]${NC} Debug mode enabled"
fi

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

print_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    print_debug "Checking kubectl configuration..."

    # Check if kubectl is configured
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "kubectl is not configured or cluster is not accessible"
        print_error "Please run: aws eks update-kubeconfig --region ap-south-1 --name <cluster-name>"
        kubectl cluster-info 2>&1 || true
        exit 1
    fi

    print_debug "kubectl check passed"

    # Check if helm is installed
    if ! command -v helm >/dev/null 2>&1; then
        print_error "Helm is not installed. Please install Helm 3.x"
        exit 1
    fi

    print_debug "Helm version: $(helm version --short 2>/dev/null || echo 'unknown')"

    # Check if values file exists
    if [ ! -f "$VALUES_FILE" ]; then
        print_error "Values file not found: $VALUES_FILE"
        exit 1
    fi

    print_debug "Values file found at: $VALUES_FILE"
    print_status "Prerequisites check passed"
}

# Function to setup Helm repo
setup_helm_repo() {
    print_status "Setting up Helm repository..."
    print_debug "Adding/updating Helm repo: $HELM_REPO"

    # Add or update the Helm repository
    if helm repo list 2>/dev/null | grep -q "$HELM_REPO"; then
        print_debug "Repository exists, updating..."
        helm repo update "$HELM_REPO" 2>&1 | while read -r line; do print_debug "$line"; done
    else
        print_debug "Adding new repository..."
        helm repo add "$HELM_REPO" "$HELM_REPO_URL" 2>&1 | while read -r line; do print_debug "$line"; done
    fi

    print_debug "Helm repo list:"
    helm repo list 2>/dev/null | while read -r line; do print_debug "$line"; done
    print_status "Helm repository ready"
}

# Function to create namespace if it doesn't exist
create_namespace() {
    print_status "Ensuring namespace exists..."
    print_debug "Checking namespace: $NAMESPACE"

    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        print_debug "Creating namespace: $NAMESPACE"
        kubectl create namespace "$NAMESPACE" 2>&1 | while read -r line; do print_debug "$line"; done
        print_status "Created namespace: $NAMESPACE"
    else
        print_debug "Namespace already exists: $NAMESPACE"
        print_status "Namespace already exists: $NAMESPACE"
    fi
}

# Function to deploy monitoring stack
deploy_monitoring() {
    print_status "Deploying monitoring stack..."
    print_debug "Checking if release exists: $RELEASE_NAME"

    # Check if release already exists
    if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$RELEASE_NAME"; then
        print_warning "Release $RELEASE_NAME already exists. Upgrading..."
        print_debug "Running helm upgrade..."
        helm upgrade "$RELEASE_NAME" "$HELM_REPO/$HELM_CHART" \
            -f "$VALUES_FILE" \
            -n "$NAMESPACE" \
            --wait \
            --timeout 600s \
            2>&1 | while read -r line; do print_debug "$line"; done
    else
        print_debug "Installing new release..."
        helm install "$RELEASE_NAME" "$HELM_REPO/$HELM_CHART" \
            -f "$VALUES_FILE" \
            -n "$NAMESPACE" \
            --create-namespace \
            --wait \
            --timeout 600s \
            2>&1 | while read -r line; do print_debug "$line"; done
    fi

    print_status "Monitoring stack deployment completed"
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    print_debug "Waiting for pods to be ready..."

    # Wait for pods to be ready
    print_debug "Running kubectl wait for pods..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance="$RELEASE_NAME" -n "$NAMESPACE" --timeout=300s \
        2>&1 | while read -r line; do print_debug "$line"; done

    # Check pod status
    print_status "Pod status:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" \
        2>&1 | while read -r line; do print_debug "$line"; done

    # Check services
    print_status "Service status:"
    kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" \
        2>&1 | while read -r line; do print_debug "$line"; done

    # Get Grafana admin password if needed
    if kubectl get secret -n "$NAMESPACE" "$RELEASE_NAME-grafana" >/dev/null 2>&1; then
        GRAFANA_PASSWORD=$(kubectl get secret -n "$NAMESPACE" "$RELEASE_NAME-grafana" -o jsonpath="{.data.admin-password}" | base64 --decode)
        print_status "Grafana admin password: $GRAFANA_PASSWORD"
        print_debug "Grafana secret retrieved successfully"
    else
        print_warning "Grafana secret not found"
    fi

    print_status "Verification completed"
}
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
    print_debug "Starting deployment script"
    print_debug "Configuration:"
    print_debug "  NAMESPACE: $NAMESPACE"
    print_debug "  RELEASE_NAME: $RELEASE_NAME"
    print_debug "  VALUES_FILE: $VALUES_FILE"
    print_debug "  HELM_REPO: $HELM_REPO"
    print_debug "  HELM_CHART: $HELM_CHART"

    check_prerequisites
    setup_helm_repo
    create_namespace
    deploy_monitoring
    verify_deployment
    display_access_info

    print_status "🎉 Monitoring stack deployment successful!"
    print_debug "Script completed successfully"
}

# Run main function
main "$@"