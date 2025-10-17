# 🔧 Certificate Status Analysis

## Current Certificate Status

From your pipeline output:

```
Certificates ready: 3/5
Warning: Timeout waiting for certificates. Check manually.

NAMESPACE    NAME                         READY   SECRET                      AGE
monitoring   grafana-nainika-store-cert   True    grafana-nainika-store-tls   49m  ✅ WORKING
prod         prod-nainika-store-cert      False   prod-nainika-store-tls      49m  ❌ FAILING
prod         prod-nainika-store-tls       True    prod-nainika-store-tls      13h  ✅ OLD SECRET
stage        stage-nainika-store-cert     False   stage-nainika-store-tls     49m  ❌ FAILING
stage        stage-nainika-store-tls      True    stage-nainika-store-tls     72m  ✅ OLD SECRET
```

## Analysis

### ✅ **What's Working:**
- **Grafana certificate**: `grafana-nainika-store-cert` is `True` 
- **DNS configured**: `grafana.nainika.store` resolves correctly
- **Old secrets exist**: Prod and stage have old TLS secrets from previous successful issuances

### ❌ **What's Failing:**
- **Prod certificate**: `prod-nainika-store-cert` is `False`
- **Stage certificate**: `stage-nainika-store-cert` is `False`
- **DNS missing**: `prod.nainika.store` and `stage.nainika.store` likely don't resolve

### 🎯 **Root Cause:**
**DNS is configured for `grafana.nainika.store` but NOT for `prod.nainika.store` and `stage.nainika.store`**

### 📋 **Evidence:**
1. **Grafana works**: Certificate issued successfully → DNS is configured
2. **Prod/Stage fail**: Certificate requests timeout → DNS not configured  
3. **Old secrets exist**: Previous successful issuances when DNS was configured
4. **LoadBalancer exists**: `aae13e3d4a32846a9bbcedf7e24da5a0-90b7a59b913c9ac3.elb.ap-south-1.amazonaws.com`

## Required Actions

### 1. Configure DNS Records
Add these CNAME records in Route53 (or your DNS provider):

```
prod.nainika.store     CNAME → aae13e3d4a32846a9bbcedf7e24da5a0-90b7a59b913c9ac3.elb.ap-south-1.amazonaws.com
stage.nainika.store    CNAME → aae13e3d4a32846a9bbcedf7e24da5a0-90b7a59b913c9ac3.elb.ap-south-1.amazonaws.com
```

### 2. Verify DNS Resolution
```bash
nslookup prod.nainika.store
nslookup stage.nainika.store
nslookup grafana.nainika.store  # Should work
```

### 3. Force Certificate Renewal (After DNS is Fixed)
```bash
# Delete failing certificates to force renewal
kubectl delete certificate prod-nainika-store-cert -n prod
kubectl delete certificate stage-nainika-store-cert -n stage

# Watch renewal
kubectl get certificates -A -w
```

## Expected Result After DNS Fix

```
NAMESPACE    NAME                         READY   SECRET                      AGE
monitoring   grafana-nainika-store-cert   True    grafana-nainika-store-tls   49m
prod         prod-nainika-store-cert      True    prod-nainika-store-tls      ~5m
stage        stage-nainika-store-cert     True    stage-nainika-store-tls     ~5m
```

## Why Old Secrets Exist

The old TLS secrets (13h and 72m) suggest that certificates were successfully issued previously, but:
- DNS configuration changed
- LoadBalancer IP changed  
- Certificate requests are failing now due to DNS resolution issues

## Next Steps

1. **Configure DNS** for prod and stage domains
2. **Wait 5-15 minutes** for DNS propagation  
3. **Trigger pipeline again** or wait for automatic renewal
4. **Verify certificates** become ready
5. **Test HTTPS access** to all domains

---

## Prometheus CRD Fix Applied ✅

Also fixed the Prometheus CRD URLs to use the correct `prometheus-operator` repository instead of the incorrect `prometheus-community` paths.

**Before:** `https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/crds/crd-*.yaml` (404)

**After:** `https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_*.yaml` (✅ Working)

This should resolve the Prometheus installation failure.