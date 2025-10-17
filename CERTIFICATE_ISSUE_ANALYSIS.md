# Certificate Generation Issue - Root Cause Analysis

## Problem Statement
Certificates created via cert-manager remain in `READY: False` state and are not being issued by Let's Encrypt.

```
NAMESPACE    NAME                         READY   SECRET                      AGE
monitoring   grafana-nainika-store-cert   False   grafana-nainika-store-tls   6m35s
prod         prod-nainika-store-cert      False   prod-nainika-store-tls      6m35s
stage        stage-nainika-store-cert     False   stage-nainika-store-tls     6m34s
```

## Root Causes Identified

### 1. **Missing cert-manager Annotation in Ingress** ⚠️ PRIMARY ISSUE
**Location**: `k8s/helm/frontend-app/values.yaml` (line 36)

**Current State**:
```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    # cert-manager.io/cluster-issuer: "cloudflare-issuer"  <-- COMMENTED OUT!
```

**Problem**: The critical cert-manager annotation is commented out! Without this annotation, cert-manager doesn't know which issuer to use and won't attempt to create certificates.

**Solution**: Uncomment and update the annotation:
```yaml
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
  cert-manager.io/cluster-issuer: "letsencrypt-prod"  # <-- Enable this
```

---

### 2. **Ingress TLS Configuration Missing**
**Location**: `k8s/helm/frontend-app/values.yaml` (lines 42-46)

**Current State**:
```yaml
  # tls:
  #   - secretName: nainika-store-tls
  #     hosts:
  #       - nainika.store
```

**Problem**: The TLS configuration is commented out. The ingress needs to explicitly declare which domains to generate certificates for.

**Solution**: Uncomment and configure properly:
```yaml
tls:
  - secretName: prod-nainika-store-tls
    hosts:
      - prod.nainika.store
  - secretName: stage-nainika-store-tls
    hosts:
      - stage.nainika.store
```

---

### 3. **DNS Not Resolving to LoadBalancer** ⚠️ BLOCKING ISSUE
**Problem**: For Let's Encrypt HTTP-01 challenge to succeed:
- Domain `prod.nainika.store` must resolve to LoadBalancer IP
- Domain `stage.nainika.store` must resolve to LoadBalancer IP
- Domain `grafana.nainika.store` must resolve to LoadBalancer IP

**Current Status**: DNS is likely NOT configured (domains still pointing to old/non-existent IPs)

**LoadBalancer IP**: `aae13e3d4a32846a9bbcedf7e24da5a0-90b7a59b913c9ac3.elb.ap-south-1.amazonaws.com`

**Solution**: Update DNS records (Route53 or your DNS provider):
```
prod.nainika.store     CNAME  aae13e3d4a32846a9bbcedf7e24da5a0-90b7a59b913c9ac3.elb.ap-south-1.amazonaws.com
stage.nainika.store    CNAME  aae13e3d4a32846a9bbcedf7e24da5a0-90b7a59b913c9ac3.elb.ap-south-1.amazonaws.com
grafana.nainika.store  CNAME  aae13e3d4a32846a9bbcedf7e24da5a0-90b7a59b913c9ac3.elb.ap-south-1.amazonaws.com
```

---

### 4. **HTTP Port Not Exposed for ACME Challenge**
**Problem**: Let's Encrypt uses HTTP-01 challenge which requires:
- Access to `http://<domain>/.well-known/acme-challenge/<token>`
- Port 80 must be publicly accessible
- Ingress must route this traffic to cert-manager's solver pod

**Current Status**: 
- Ingress has `nginx.ingress.kubernetes.io/ssl-redirect: "true"` which redirects HTTP to HTTPS
- But ACME challenge happens BEFORE certificate exists (chicken-and-egg problem)

**Solution**: The ingress template needs `ssl-redirect: "false"` during certificate creation:
```yaml
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /
  nginx.ingress.kubernetes.io/ssl-redirect: "false"  # Allow HTTP for ACME
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

---

### 5. **Cert-manager Webhook Status**
**Problem**: Cert-manager webhook must be running and accessible:
```bash
kubectl get deployment -n cert-manager
kubectl get pods -n cert-manager
kubectl logs -n cert-manager deployment/cert-manager
```

**Symptoms of webhook issues**:
- Certificate stays in `Creating` state
- No orders or challenges created
- Check with: `kubectl describe cert prod-nainika-store-cert -n prod`

---

## Step-by-Step Fix

### Step 1: Fix Ingress Configuration
```bash
cd /Users/mac/Downloads/hrgf-task
# Update values.yaml with cert-manager annotation and TLS config
```

### Step 2: Verify Cert-manager is Running
```bash
# Check if cert-manager is deployed
kubectl get pods -n cert-manager

# Check webhook
kubectl get validatingwebhookconfigurations

# Check ClusterIssuers
kubectl get clusterissuer
```

### Step 3: Configure DNS
Update your Route53 or DNS provider to point all domains to the LoadBalancer DNS name.

### Step 4: Redeploy
```bash
# Delete existing certificates to force renewal
kubectl delete certificates -n prod
kubectl delete certificates -n stage
kubectl delete certificates -n monitoring

# Redeploy with fixed configuration
helm upgrade --install frontend-app-prod ./k8s/helm/frontend-app \
  -f ./k8s/helm/frontend-app/value-prod.yaml \
  -n prod

helm upgrade --install frontend-app-stage ./k8s/helm/frontend-app \
  -f ./k8s/helm/frontend-app/value-stage.yaml \
  -n stage
```

### Step 5: Monitor Certificate Creation
```bash
# Watch certificates being created
kubectl get certificates -A -w

# Check certificate details
kubectl describe cert prod-nainika-store-cert -n prod
kubectl describe cert stage-nainika-store-cert -n stage
kubectl describe cert grafana-nainika-store-cert -n monitoring

# Check ACME orders and challenges
kubectl get orders -A
kubectl get challenges -A
kubectl describe challenge <name> -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager -f
kubectl logs -n cert-manager deployment/cert-manager-webhook -f
```

---

## Summary of Issues

| # | Issue | Severity | Location | Fix |
|---|-------|----------|----------|-----|
| 1 | Missing cert-manager annotation | **CRITICAL** | values.yaml:36 | Uncomment `cert-manager.io/cluster-issuer: letsencrypt-prod` |
| 2 | TLS config commented out | **CRITICAL** | values.yaml:42-46 | Uncomment and configure TLS section |
| 3 | DNS not pointing to LB | **BLOCKING** | External (Route53) | Update DNS records to point to LoadBalancer |
| 4 | SSL redirect blocks ACME | **HIGH** | values.yaml:34 | Set `ssl-redirect: false` or use ACME solver ingress |
| 5 | Cert-manager webhook down | **MEDIUM** | Kubernetes | Verify cert-manager pods are running |

---

## Verification Commands

Once fixed, run these to verify:

```bash
# 1. Check if certificates are being issued
kubectl get certificates -A

# 2. Check if DNS resolves
nslookup prod.nainika.store
nslookup stage.nainika.store
nslookup grafana.nainika.store

# 3. Test HTTP access (should reach ingress)
curl -v http://prod.nainika.store

# 4. Check if secrets are created
kubectl get secrets -A | grep tls

# 5. View certificate details
kubectl get secret prod-nainika-store-tls -n prod -o yaml

# 6. Check ingress
kubectl get ingress -A
```
