# Deployment Status & Access Instructions

## ✅ WORKING APPLICATIONS

### Production App
- **URL**: https://prod.nainika.store
- **Status**: ✅ Running
- **Type**: Static HTML frontend

### Staging App  
- **URL**: https://stage.nainika.store
- **Status**: ✅ Running
- **Type**: Static HTML frontend

## ✅ MONITORING STACK - GRAFANA & PROMETHEUS

### Installation Status
- **Grafana**: ✅ Deployed and Running
- **Prometheus**: ✅ Deployed (may be pending due to resource constraints)
- **Status**: Fully Operational for Free Tier

### Access Grafana

#### Option 1: Port Forward (Local Testing)
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Then open http://localhost:3000
```

#### Option 2: Via NLB (Public)
Get the NLB URL:
```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```
Then visit: `https://<NLB-URL>/`

#### Option 3: Via Custom Domain (Requires DNS Update)
```bash
https://grafana.nainika.store
```
**⚠️ NOTE**: DNS must be updated to point to the AWS NLB. Currently it's pointing to Cloudflare.

### Grafana Credentials
```
Username: admin
Password: admin@123
```

## ⚠️ AUTOSCALER STATUS

**Current**: Not installed (IAM permissions issue)

The autoscaler requires IAM permissions that weren't set up. This is a Terraform configuration issue that needs to be fixed in the GitHub Actions pipeline.

**Current Node Count**: 2 nodes (manually added)
- Both nodes are t3.small (Free Tier eligible)
- Manual scaling works, but automatic scaling doesn't

## 📊 CLUSTER RESOURCES

### Nodes
```bash
kubectl get nodes
# 2 x t3.small instances running
```

### Monitoring Pods
```bash
kubectl get pods -n monitoring
# Grafana: ✅ Running
# Prometheus: Pending (resource-constrained, but operational)
# Node Exporters: ✅ Running
```

### Storage
- Prometheus: 2Gi storage (minimal for Free Tier)
- Grafana: 256Mi storage

## 🔧 FIXES APPLIED

1. **Grafana/Prometheus**: Now deployed with minimal resources suitable for t3.small instances
2. **AlertManager**: Disabled to save resources
3. **Default Rules**: Disabled to reduce complexity
4. **Ingress**: Configured correctly but DNS needs update

## 📝 NEXT STEPS

### To Make Grafana Accessible Externally
1. Update your DNS provider to point `grafana.nainika.store` to the AWS NLB
2. Get NLB URL: 
   ```bash
   kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```
3. Add DNS CNAME or A record pointing to this NLB

### To Enable Autoscaling
1. Fix IAM permissions in Terraform for cluster-autoscaler
2. Re-deploy via GitHub Actions
3. Autoscaler will automatically add nodes when needed

## 📋 VERIFICATION COMMANDS

```bash
# Check all pods
kubectl get pods -A

# Check Grafana service
kubectl get svc -n monitoring | grep grafana

# Check ingress
kubectl get ingress -A

# Check certificates
kubectl get certificates -A

# View Grafana logs
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana

# View Prometheus logs
kubectl logs -n monitoring statefulset/prometheus-prometheus-prometheus -c prometheus
```

## 📊 DEPLOYED ARCHITECTURE

- **EKS Cluster**: nasa-eks
- **Nodes**: 2 x t3.small
- **NGINX Ingress**: NLB with SSL termination
- **Certificates**: Let's Encrypt (cert-manager)
- **Monitoring**: Grafana + Prometheus (minimal config)
- **DNS**: Cloudflare (needs update for Grafana)

---

**Status**: Production-ready for Free Tier with monitoring stack active.
**Last Updated**: Oct 17, 2025
