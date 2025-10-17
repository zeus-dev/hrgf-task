# Deployment Ready - Infrastructure & Monitoring Stack

## ✅ Completed Configuration

All infrastructure and monitoring components are now configured and ready for deployment via CI/CD pipeline.

### 1. **Terraform Infrastructure Updates** ✅

#### `terraform/variables.tf`
- **Change**: Updated node count configuration
  - `desired_size`: 2 → **4 nodes**
  - `max_size`: 2 → **4 nodes** (already correct)
  - `min_size`: 1 (unchanged)

#### `terraform/autoscaler.tf` (NEW FILE) ✅
- **Purpose**: Enables automatic cluster scaling
- **Components**:
  - IAM Role for cluster-autoscaler service account
  - IAM Policy with AWS permissions:
    - `autoscaling:DescribeAutoScalingGroups`
    - `autoscaling:SetDesiredCapacity`
    - `autoscaling:TerminateInstanceInAutoScalingGroup`
    - EC2 describe permissions
  - Auto Scaling Group tagging for discovery
  - Output: `cluster_autoscaler_role_arn` (used by pipeline)

### 2. **CI/CD Pipeline Updates** ✅

#### `.github/workflows/terraform-apply.yaml`
**Key Changes**:
1. **Parse Terraform Outputs**:
   - Added extraction of `cluster_autoscaler_role_arn` from Terraform output
   - Output now exports both cluster name and autoscaler role ARN

2. **Cluster Autoscaler Installation**:
   - **Before**: Used hardcoded IAM role ARN ❌
   - **After**: Uses dynamic `${{ steps.outputs.outputs.autoscaler_role_arn }}` ✅
   - Configured with:
     - Auto-discovery of cluster resources
     - Node group balance enabled
     - Scale-down threshold: 70% utilization
     - Scale-down timeout: 2 minutes

### 3. **Monitoring Stack Optimization** ✅

#### `k8s/monitoring/prometheus-values.yaml`

**Prometheus** (RE-ENABLED):
- Enabled: `true` (was disabled)
- Replicas: 1
- Resources:
  - Requests: 50m CPU / 256Mi memory
  - Limits: 100m CPU / 512Mi memory
- Retention: 24 hours
- Persistence: Disabled (ephemeral storage)
- Storage: 5Gi PVC

**Grafana** (Optimized):
- Resources: 50m CPU / 128Mi memory (minimal)
- Replicas: 1
- Persistence: Disabled
- Ingress: Enabled with TLS via cert-manager

**Kube State Metrics** (RE-ENABLED):
- Enabled: `true` (was disabled)
- Resources: 10m CPU / 24Mi memory (minimal)

**AlertManager** (RE-ENABLED):
- Enabled: `true` (was disabled)
- Replicas: 1
- Resources: 10m CPU / 32Mi memory (minimal)
- Storage: 1Gi PVC

**Default Rules** (Optimized):
- Enabled with selective rules to reduce overhead
- Focuses on: Kubernetes core, node health, Prometheus operator

**Node Exporter**:
- Resources: 10m CPU / 16Mi memory (minimal)

## 📊 Resource Allocation Summary

### Total Cluster Resources (4 x t3.small = 4 vCPU / 16 GB RAM)

#### Production Application
- Replicas: 1-2
- Per replica: 10m CPU / 16Mi memory

#### Staging Application
- Replicas: 1
- Per replica: 10m CPU / 16Mi memory

#### Monitoring Stack (Total ~200m CPU / 700Mi memory)
- Prometheus: 50m CPU / 256Mi memory
- Grafana: 50m CPU / 128Mi memory
- AlertManager: 10m CPU / 32Mi memory
- Kube State Metrics: 10m CPU / 24Mi memory
- Node Exporter (per node): 10m CPU / 16Mi memory × 4 nodes = 40m CPU / 64Mi memory
- Prometheus Operator: ~20m CPU / 64Mi memory

#### System Pods (kubectl, DNS, etc.): ~150m CPU / 400Mi memory

**Total Estimated**: ~400m CPU / 1.2GB memory ≈ **10% CPU / 7.5% Memory** utilization on 4-node cluster ✅

## 🚀 Deployment Steps

### Step 1: Review Changes
```bash
cd /Users/mac/Downloads/hrgf-task
git status
git diff
```

### Step 2: Commit Changes
```bash
git add terraform/ k8s/ .github/
git commit -m "feat: scale to 4 nodes, enable autoscaler with IRSA, re-enable Prometheus stack"
```

### Step 3: Push to Trigger Pipeline
```bash
git push origin main
```

### Step 4: Monitor Pipeline Execution
- GitHub Actions will automatically:
  1. ✅ Validate Terraform configuration
  2. ✅ Apply Terraform → Creates 4-node cluster + autoscaler IAM role
  3. ✅ Update kubeconfig and create namespaces
  4. ✅ Install cert-manager
  5. ✅ Install NGINX ingress controller with NLB
  6. ✅ Configure TLS certificates via cert-manager
  7. ✅ Install Prometheus stack with:
     - Grafana UI (accessible at https://grafana.nainika.store)
     - Prometheus metrics collection
     - AlertManager for alerting
     - Kube State Metrics for cluster state
  8. ✅ Deploy cluster-autoscaler for automatic scaling

### Step 5: Verify Deployment
```bash
# Check nodes scaled to 4
kubectl get nodes

# Verify autoscaler is running
kubectl get pods -n kube-system | grep autoscaler

# Check monitoring stack
kubectl get pods -n monitoring

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open http://localhost:3000
# Login: admin / admin@123
```

## 🔍 Pipeline Output Information

After deployment completes, the pipeline will display:
- Cluster name
- AWS region: ap-south-1
- LoadBalancer DNS for ingress
- DNS configuration instructions

## ⚠️ Important Notes

1. **Autoscaler Tagging**: The autoscaler is configured to discover ASG via k8s.io/cluster-autoscaler tag
2. **IRSA**: IAM Roles for Service Accounts (IRSA) uses OIDC provider for secure authentication
3. **Node Scaling**: New nodes will be provisioned automatically when pods are pending due to resource constraints
4. **Persistence**: Prometheus and AlertManager use ephemeral storage (no EBS volumes)
5. **DNS**: Ensure DNS records point to the LoadBalancer DNS provided in pipeline output

## 📝 Files Modified

| File | Changes | Status |
|------|---------|--------|
| `terraform/variables.tf` | Node count: 2→4 | ✅ Ready |
| `terraform/autoscaler.tf` | NEW - Autoscaler IAM setup | ✅ Ready |
| `.github/workflows/terraform-apply.yaml` | Dynamic IAM role ARN extraction | ✅ Ready |
| `k8s/monitoring/prometheus-values.yaml` | Enable Prometheus/AlertManager with optimized resources | ✅ Ready |

## ✨ Benefits

✅ **Auto-scaling**: Cluster automatically scales from 2→4 nodes based on workload
✅ **Full Monitoring**: Grafana, Prometheus, and AlertManager all enabled
✅ **Secure IRSA**: Autoscaler uses IAM role without AWS credentials in pod
✅ **Resource Efficient**: Optimized for Free Tier t3.small instances
✅ **GitOps Ready**: All changes tracked in git, deployable via CI/CD

---

**Next Action**: Commit and push changes to trigger automatic deployment pipeline.
