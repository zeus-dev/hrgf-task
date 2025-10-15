# Prometheus and Grafana Stack for Monitoring

This directory contains the monitoring stack configuration for the Nainika Store infrastructure.

## Components

### Prometheus
- Metrics collection and storage
- Service discovery for Kubernetes
- Alert manager integration

### Grafana
- Visualization dashboards
- Pre-configured dashboards for:
  - NGINX Ingress Controller (Dashboard ID: 14314)
  - Kubernetes Cluster Monitoring (Dashboard ID: 7249)
  - Kubernetes Pods Monitoring (Dashboard ID: 6417)
  - Node Exporter Full (Dashboard ID: 1860)
  - Prometheus 2.0 Overview (Dashboard ID: 3662)

## Installation

```bash
# Add Prometheus community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -f prometheus-values.yaml \
  -n monitoring \
  --create-namespace

# Install Grafana (included in kube-prometheus-stack)
# Grafana will be available at grafana.nainika.store
```

## Access

- **Prometheus**: https://prometheus.nainika.store
- **Grafana**: https://grafana.nainika.store
- **Alert Manager**: https://alertmanager.nainika.store

## Default Credentials

- **Grafana**: 
  - Username: admin
  - Password: (check secret in monitoring namespace)

```bash
kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```