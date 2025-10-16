# Quick Reference Guide

## 🚀 Quick Commands

### Infrastructure Setup

```bash
# Complete automated setup
./scripts/setup-infrastructure.sh

# Backend only
./scripts/setup-backend.sh

# Manual Terraform
cd terraform
terraform init
terraform plan
terraform apply
```

### Kubernetes Access

```bash
# Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name nasa-eks

# View cluster
kubectl get nodes
kubectl get pods -A
kubectl get svc -A
kubectl get ingress -A
```

### Application Deployment

```bash
# Production
helm upgrade --install frontend-app-prod ./k8s/helm/frontend-app \
  -f ./k8s/helm/frontend-app/value-prod.yaml \
  -n prod --create-namespace

# Staging
helm upgrade --install frontend-app-stage ./k8s/helm/frontend-app \
  -f ./k8s/helm/frontend-app/value-stage.yaml \
  -n stage --create-namespace
```

### Monitoring

```bash
# Get Grafana password
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Port forward Grafana (local access)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Port forward Prometheus (local access)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

### Troubleshooting

```bash
# Check pod status
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs -f <pod-name> -n <namespace>

# Check ingress
kubectl get ingress -A
kubectl describe ingress <ingress-name> -n <namespace>

# Check NGINX controller
kubectl logs -f -n ingress-nginx deployment/ingress-nginx-controller

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Get LoadBalancer DNS

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Cleanup

```bash
# Automated cleanup
./scripts/cleanup-infrastructure.sh

# Manual cleanup
cd terraform
terraform destroy
```

## 🌐 URLs

After DNS configuration:
- **Grafana**: http://grafana.nainika.store
- **Production**: http://prod.nainika.store
- **Staging**: http://stage.nainika.store

## 🔐 GitHub Secrets Required

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
DOCKER_HUB_USERNAME
DOCKER_HUB_ACCESS_TOKEN
GRAFANA_ADMIN_PASSWORD (optional)
```

## 📊 Pre-configured Grafana Dashboards

1. NGINX Ingress Controller (14314)
2. Kubernetes Cluster Monitoring (7249)
3. Kubernetes Pods Monitoring (6417)
4. Node Exporter Full (1860)
5. Prometheus 2.0 Overview (3662)

## 🏷️ Image Tags

- Production: `prod-<commit-sha>`
- Staging: `staging-<commit-sha>`
- Latest: `latest` (production only)

## 📁 Key Files

- `terraform/backend.tf` - Terraform backend config
- `terraform/variables.tf` - Input variables
- `k8s/helm/frontend-app/value-prod.yaml` - Production values
- `k8s/helm/frontend-app/value-stage.yaml` - Staging values
- `k8s/monitoring/prometheus-values.yaml` - Monitoring config
- `.github/workflows/` - CI/CD pipelines

## 🆘 Common Issues

### Issue: Terraform backend not initialized
```bash
./scripts/setup-backend.sh
cd terraform
terraform init
```

### Issue: Pods not starting
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Issue: Ingress not working
```bash
kubectl get svc -n ingress-nginx
kubectl logs -f -n ingress-nginx deployment/ingress-nginx-controller
```

### Issue: DNS not resolving
- Wait for DNS propagation (5-30 minutes)
- Verify CNAME records in Cloudflare
- Check LoadBalancer is active

## 💰 Cost Estimate

- EKS Control Plane: ~$73/month
- EC2 t3.small (2 nodes): ~$30/month
- EBS volumes: ~$3/month
- NAT Gateway: ~$32/month
- **Total: ~$138/month**

Free tier eligible for first year:
- EC2: 750 hours/month free
- EBS: 30 GB free

## 📚 Documentation

- [Full Deployment Guide](docs/DEPLOYMENT.md)
- [Best Practices](docs/BEST_PRACTICES.md)
- [Monitoring Setup](k8s/monitoring/README.md)
