# AWS EKS Infrastructure - Deployment Guide

This guide provides step-by-step instructions to deploy the complete AWS EKS infrastructure with monitoring and CI/CD automation.

## 📋 Prerequisites

### Required Tools
- AWS CLI (v2.x or later)
- Terraform (v1.0 or later)
- kubectl (v1.28 or later)
- Helm (v3.x or later)
- Docker (for local testing)
- Git

### AWS Account Setup
- AWS Account with appropriate permissions
- AWS CLI configured with access credentials
- Sufficient AWS service limits (especially for VPC, EKS, and EC2)

### GitHub Setup
- GitHub account
- Repository secrets configured (see below)

## 🔐 Required GitHub Secrets

Configure the following secrets in your GitHub repository:

```
AWS_ACCESS_KEY_ID          # AWS access key for deployment
AWS_SECRET_ACCESS_KEY      # AWS secret key for deployment
DOCKER_HUB_USERNAME        # Docker Hub username
DOCKER_HUB_ACCESS_TOKEN    # Docker Hub access token
GRAFANA_ADMIN_PASSWORD     # Grafana admin password (optional, defaults to admin123!)
```

## 🚀 Deployment Steps

### Method 1: Automated Setup (Recommended)

```bash
# 1. Clone the repository
git clone https://github.com/zeus-dev/hrgf-task.git
cd hrgf-task

# 2. Set environment variables (optional)
export AWS_REGION=ap-south-1
export CLUSTER_NAME=nasa-eks

# 3. Run the automated setup script
./scripts/setup-infrastructure.sh
```

The script will:
- ✅ Verify all prerequisites
- ✅ Create S3 bucket and DynamoDB table for Terraform state
- ✅ Initialize and apply Terraform configuration
- ✅ Configure kubectl
- ✅ Deploy all Kubernetes components
- ✅ Provide access information

### Method 2: Manual Setup

#### Step 1: Setup Terraform Backend

```bash
# Run the backend setup script
./scripts/setup-backend.sh

# Or manually create resources
aws s3api create-bucket \
    --bucket nainika-terraform-state \
    --region ap-south-1 \
    --create-bucket-configuration LocationConstraint=ap-south-1

aws s3api put-bucket-versioning \
    --bucket nainika-terraform-state \
    --versioning-configuration Status=Enabled

aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region ap-south-1
```

#### Step 2: Initialize Terraform

```bash
cd terraform

# Uncomment the backend configuration in backend.tf
# Then initialize Terraform
terraform init

# Format and validate
terraform fmt -recursive
terraform validate
```

#### Step 3: Apply Terraform Configuration

```bash
# Create execution plan
terraform plan -out=tfplan

# Review the plan and apply
terraform apply tfplan

# Note the outputs
terraform output
```

#### Step 4: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name nasa-eks

# Verify cluster access
kubectl get nodes
kubectl get namespaces
```

#### Step 5: Verify Deployments

```bash
# Check all pods are running
kubectl get pods -A

# Check services
kubectl get svc -A

# Check ingress
kubectl get ingress -A
```

## 🌐 DNS Configuration

### Get LoadBalancer DNS

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Configure Cloudflare DNS

Add the following CNAME records in Cloudflare:

| Type  | Name                 | Target                        | Proxy Status |
|-------|----------------------|-------------------------------|--------------|
| CNAME | grafana.nainika.store| <LoadBalancer-DNS>            | Proxied      |
| CNAME | prod.nainika.store   | <LoadBalancer-DNS>            | Proxied      |
| CNAME | stage.nainika.store  | <LoadBalancer-DNS>            | Proxied      |

## 📊 Access Monitoring

### Get Grafana Password

```bash
kubectl get secret --namespace monitoring kube-prometheus-stack-grafana \
    -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

### Access Grafana

- URL: http://grafana.nainika.store (after DNS propagation)
- Username: `admin`
- Password: (from above command)

### Pre-configured Dashboards

1. **NGINX Ingress Controller** (ID: 14314)
2. **Kubernetes Cluster Monitoring** (ID: 7249)
3. **Kubernetes Pods Monitoring** (ID: 6417)
4. **Node Exporter Full** (ID: 1860)
5. **Prometheus 2.0 Overview** (ID: 3662)

## 🔄 CI/CD Pipeline

### Automated Workflows

1. **Infrastructure Pipeline** (`terraform-apply.yaml`)
   - Trigger: Changes to `terraform/` on `master` branch
   - Actions: Terraform validate, plan, apply
   - Automatically deploys infrastructure changes

2. **Production Deployment** (`build-deploy-prod.yaml`)
   - Trigger: Changes to `frontend/` on `main` branch
   - Actions: Build Docker image → Push to registry → Deploy to prod namespace

3. **Staging Deployment** (`build-deploy-stage.yaml`)
   - Trigger: Changes to `frontend/` on `develop` branch
   - Actions: Build Docker image → Push to registry → Deploy to stage namespace

### Manual Deployment

```bash
# Deploy to production
helm upgrade --install frontend-app-prod ./k8s/helm/frontend-app \
    -f ./k8s/helm/frontend-app/value-prod.yaml \
    -n prod \
    --create-namespace

# Deploy to staging
helm upgrade --install frontend-app-stage ./k8s/helm/frontend-app \
    -f ./k8s/helm/frontend-app/value-stage.yaml \
    -n stage \
    --create-namespace
```

## 🧪 Testing

### Local Docker Build

```bash
cd frontend

# Build the image
docker build -t zeusdev27/myhello-app:local .

# Run locally
docker run -p 8080:8080 zeusdev27/myhello-app:local

# Access at http://localhost:8080
```

### Test Kubernetes Manifests

```bash
# Dry-run Helm chart
helm template ./k8s/helm/frontend-app \
    -f ./k8s/helm/frontend-app/values.yaml

# Validate manifests
kubectl apply --dry-run=client -f k8s/namespaces/namespaces.yaml
```

## 🔍 Troubleshooting

### Check Pod Status

```bash
# All pods
kubectl get pods -A

# Specific namespace
kubectl get pods -n prod

# Pod logs
kubectl logs -f <pod-name> -n <namespace>

# Describe pod
kubectl describe pod <pod-name> -n <namespace>
```

### Check Ingress

```bash
# View all ingress
kubectl get ingress -A

# Describe ingress
kubectl describe ingress <ingress-name> -n <namespace>

# Check NGINX controller logs
kubectl logs -f deployment/ingress-nginx-controller -n ingress-nginx
```

### Check Services

```bash
# All services
kubectl get svc -A

# Check endpoints
kubectl get endpoints -A
```

### Common Issues

#### 1. Pods not starting
- Check logs: `kubectl logs <pod-name> -n <namespace>`
- Check events: `kubectl get events -n <namespace>`
- Verify image exists in Docker Hub

#### 2. Ingress not working
- Verify LoadBalancer is active: `kubectl get svc -n ingress-nginx`
- Check DNS propagation: `nslookup grafana.nainika.store`
- Review ingress annotations

#### 3. Terraform errors
- Ensure AWS credentials are configured
- Check AWS service limits
- Review Terraform state: `terraform show`

## 🧹 Cleanup

### Using Script (Recommended)

```bash
./scripts/cleanup-infrastructure.sh
```

### Manual Cleanup

```bash
# Delete Helm releases
helm uninstall frontend-app-prod -n prod
helm uninstall frontend-app-stage -n stage
helm uninstall kube-prometheus-stack -n monitoring
helm uninstall ingress-nginx -n ingress-nginx

# Destroy infrastructure
cd terraform
terraform destroy

# Delete backend (optional)
aws s3 rb s3://nainika-terraform-state --force
aws dynamodb delete-table --table-name terraform-state-lock
```

## 📈 Cost Optimization

This infrastructure is optimized for AWS Free Tier:

- **EKS**: $0.10/hour (not free tier eligible)
- **EC2**: t3.small instances (free tier for first 750 hours/month)
- **VPC**: Single NAT Gateway to reduce costs
- **EBS**: GP2 volumes (free tier eligible up to 30GB)

**Estimated Monthly Cost**: ~$75-100 USD

To further reduce costs:
- Stop the cluster when not in use
- Use Spot instances for worker nodes
- Reduce node count to minimum

## 🔒 Security Best Practices

1. **Secrets Management**
   - Use AWS Secrets Manager or Parameter Store
   - Never commit secrets to Git
   - Rotate credentials regularly

2. **Network Security**
   - VPC with private subnets for nodes
   - Security groups with minimal required access
   - TLS encryption for all external traffic

3. **Container Security**
   - Non-root containers
   - Read-only root filesystem
   - Security contexts configured

4. **Access Control**
   - RBAC enabled on cluster
   - IAM roles for service accounts
   - Separate namespaces for environments

## 📚 Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)

## 🤝 Support

For issues or questions:
- Create an issue in the GitHub repository
- Review existing documentation
- Check logs and events for detailed error messages
