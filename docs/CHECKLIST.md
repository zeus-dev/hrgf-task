# Getting Started Checklist

Use this checklist to deploy the complete AWS EKS infrastructure step by step.

## ☑️ Pre-Deployment Checklist

### 1. Install Required Tools

- [ ] Install AWS CLI v2.x or later
  ```bash
  aws --version
  ```

- [ ] Install Terraform v1.0 or later
  ```bash
  terraform --version
  ```

- [ ] Install kubectl v1.28 or later
  ```bash
  kubectl version --client
  ```

- [ ] Install Helm v3.x or later
  ```bash
  helm version
  ```

- [ ] Install Docker (for local testing)
  ```bash
  docker --version
  ```

### 2. Configure AWS Credentials

- [ ] Configure AWS CLI
  ```bash
  aws configure
  # Enter your AWS Access Key ID
  # Enter your AWS Secret Access Key
  # Enter region: ap-south-1
  # Enter output format: json
  ```

- [ ] Verify AWS credentials
  ```bash
  aws sts get-caller-identity
  ```

### 3. Clone Repository

- [ ] Clone the repository
  ```bash
  git clone https://github.com/zeus-dev/hrgf-task.git
  cd hrgf-task
  ```

### 4. Configure GitHub Secrets

- [ ] Go to GitHub repository → Settings → Secrets and variables → Actions
- [ ] Add the following secrets:

  - [ ] `AWS_ACCESS_KEY_ID` - Your AWS access key
  - [ ] `AWS_SECRET_ACCESS_KEY` - Your AWS secret key
  - [ ] `DOCKER_HUB_USERNAME` - Your Docker Hub username
  - [ ] `DOCKER_HUB_ACCESS_TOKEN` - Your Docker Hub access token
  - [ ] `GRAFANA_ADMIN_PASSWORD` - Custom Grafana password (optional)

## 🚀 Deployment Checklist

### Option A: Automated Deployment (Recommended)

- [ ] Run the complete setup script
  ```bash
  ./scripts/setup-infrastructure.sh
  ```

- [ ] Wait for completion (15-20 minutes)
- [ ] Note the LoadBalancer DNS from output
- [ ] Note the Grafana admin password from output

### Option B: Manual Deployment

#### Step 1: Setup Backend

- [ ] Run backend setup script
  ```bash
  ./scripts/setup-backend.sh
  ```

- [ ] Verify S3 bucket created
  ```bash
  aws s3 ls | grep nainika-terraform-state
  ```

- [ ] Verify DynamoDB table created
  ```bash
  aws dynamodb list-tables | grep terraform-state-lock
  ```

#### Step 2: Deploy Infrastructure

- [ ] Navigate to terraform directory
  ```bash
  cd terraform
  ```

- [ ] Initialize Terraform
  ```bash
  terraform init
  ```

- [ ] Validate configuration
  ```bash
  terraform validate
  ```

- [ ] Create execution plan
  ```bash
  terraform plan -out=tfplan
  ```

- [ ] Review plan and apply
  ```bash
  terraform apply tfplan
  ```

- [ ] Wait for completion (15-20 minutes)

#### Step 3: Configure kubectl

- [ ] Update kubeconfig
  ```bash
  aws eks update-kubeconfig --region ap-south-1 --name nasa-eks
  ```

- [ ] Verify cluster access
  ```bash
  kubectl get nodes
  ```

- [ ] Check all namespaces
  ```bash
  kubectl get namespaces
  ```

#### Step 4: Verify Deployments

- [ ] Check all pods are running
  ```bash
  kubectl get pods -A
  ```

- [ ] Check services
  ```bash
  kubectl get svc -A
  ```

- [ ] Check ingress
  ```bash
  kubectl get ingress -A
  ```

## 🌐 DNS Configuration Checklist

### Step 1: Get LoadBalancer DNS

- [ ] Get LoadBalancer DNS
  ```bash
  kubectl get svc -n ingress-nginx ingress-nginx-controller \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
  ```

- [ ] Copy the DNS name (e.g., `a1234567890.elb.ap-south-1.amazonaws.com`)

### Step 2: Configure Cloudflare

- [ ] Log in to Cloudflare dashboard
- [ ] Select your domain `nainika.store`
- [ ] Go to DNS → Records
- [ ] Add the following CNAME records:

  - [ ] Record 1:
    - Type: `CNAME`
    - Name: `grafana`
    - Target: `<LoadBalancer-DNS>` (paste from above)
    - Proxy status: `Proxied` (orange cloud)
    - TTL: `Auto`

  - [ ] Record 2:
    - Type: `CNAME`
    - Name: `prod`
    - Target: `<LoadBalancer-DNS>`
    - Proxy status: `Proxied`
    - TTL: `Auto`

  - [ ] Record 3:
    - Type: `CNAME`
    - Name: `stage`
    - Target: `<LoadBalancer-DNS>`
    - Proxy status: `Proxied`
    - TTL: `Auto`

- [ ] Save all records
- [ ] Wait for DNS propagation (5-30 minutes)

### Step 3: Verify DNS

- [ ] Test DNS resolution
  ```bash
  nslookup grafana.nainika.store
  nslookup prod.nainika.store
  nslookup stage.nainika.store
  ```

## 📊 Access Services Checklist

### Grafana

- [ ] Get Grafana password
  ```bash
  kubectl get secret -n monitoring kube-prometheus-stack-grafana \
    -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
  ```

- [ ] Access Grafana
  - URL: http://grafana.nainika.store
  - Username: `admin`
  - Password: (from above command)

- [ ] Verify dashboards are loaded
  - [ ] NGINX Ingress Controller
  - [ ] Kubernetes Cluster Monitoring
  - [ ] Kubernetes Pods Monitoring
  - [ ] Node Exporter Full
  - [ ] Prometheus 2.0 Overview

### Frontend Applications

- [ ] Access Production
  - URL: http://prod.nainika.store
  - [ ] Verify application loads

- [ ] Access Staging
  - URL: http://stage.nainika.store
  - [ ] Verify application loads

## 🔄 CI/CD Pipeline Checklist

### Test Infrastructure Pipeline

- [ ] Make a change to `terraform/` directory
- [ ] Push to `master` branch
- [ ] Check GitHub Actions workflow runs
- [ ] Verify Terraform plan/apply completes

### Test Production Pipeline

- [ ] Make a change to `frontend/` directory
- [ ] Push to `main` branch
- [ ] Check GitHub Actions workflow runs
- [ ] Verify Docker build succeeds
- [ ] Verify deployment to production
- [ ] Check production URL

### Test Staging Pipeline

- [ ] Make a change to `frontend/` directory
- [ ] Push to `develop` branch
- [ ] Check GitHub Actions workflow runs
- [ ] Verify Docker build succeeds
- [ ] Verify deployment to staging
- [ ] Check staging URL

## ✅ Verification Checklist

### Infrastructure

- [ ] EKS cluster is running
  ```bash
  aws eks describe-cluster --name nasa-eks --region ap-south-1
  ```

- [ ] Nodes are healthy
  ```bash
  kubectl get nodes
  ```

- [ ] All pods are running
  ```bash
  kubectl get pods -A | grep -v Running | grep -v Completed
  ```

### Monitoring

- [ ] Prometheus is collecting metrics
  ```bash
  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
  # Open http://localhost:9090 and check targets
  ```

- [ ] Grafana dashboards are working
  - [ ] Open each dashboard and verify data

### Networking

- [ ] LoadBalancer has external IP
  ```bash
  kubectl get svc -n ingress-nginx ingress-nginx-controller
  ```

- [ ] All ingresses are configured
  ```bash
  kubectl get ingress -A
  ```

- [ ] DNS records are resolving
  ```bash
  dig grafana.nainika.store
  dig prod.nainika.store
  dig stage.nainika.store
  ```

### Applications

- [ ] Production app is accessible
  ```bash
  curl -I http://prod.nainika.store
  ```

- [ ] Staging app is accessible
  ```bash
  curl -I http://stage.nainika.store
  ```

- [ ] Grafana is accessible
  ```bash
  curl -I http://grafana.nainika.store
  ```

## 📝 Documentation Review

- [ ] Read [SUMMARY.md](SUMMARY.md) for overview
- [ ] Read [DEPLOYMENT.md](DEPLOYMENT.md) for detailed guide
- [ ] Read [ARCHITECTURE.md](ARCHITECTURE.md) for architecture
- [ ] Read [BEST_PRACTICES.md](BEST_PRACTICES.md) for guidelines
- [ ] Read [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for commands

## 🎉 Success Criteria

You've successfully deployed the infrastructure if:

- [x] All pods are in Running state
- [x] LoadBalancer has external DNS
- [x] All three domains are accessible:
  - grafana.nainika.store
  - prod.nainika.store
  - stage.nainika.store
- [x] Grafana shows metrics and dashboards
- [x] CI/CD pipelines are working
- [x] Applications are deployed and accessible

## 🆘 Troubleshooting

If you encounter issues:

1. **Check the logs**
   ```bash
   kubectl logs -f <pod-name> -n <namespace>
   ```

2. **Describe the resource**
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```

3. **Check events**
   ```bash
   kubectl get events -A --sort-by='.lastTimestamp'
   ```

4. **Review documentation**
   - [Deployment Guide](DEPLOYMENT.md)
   - [Quick Reference](QUICK_REFERENCE.md)

5. **Check GitHub Actions logs**
   - Go to Actions tab in GitHub
   - Review failed workflow runs

## 🧹 Cleanup (When Done)

- [ ] Run cleanup script
  ```bash
  ./scripts/cleanup-infrastructure.sh
  ```

- [ ] Verify all resources are deleted
  ```bash
  aws eks list-clusters --region ap-south-1
  ```

- [ ] Optionally delete backend
  - Script will prompt for this option

---

**Note**: Keep this checklist for reference during deployment. Check off items as you complete them.
