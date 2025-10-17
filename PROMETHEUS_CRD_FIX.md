# 🔧 Prometheus CRD Installation Fix

## Problem
The Terraform pipeline was failing with this error:
```
Error: unable to build kubernetes objects from release manifest: [resource mapping not found for name: "prometheus-alertmanager" namespace: "monitoring" from "": no matches for kind "Alertmanager" in version "monitoring.coreos.com/v1"
ensure CRDs are installed first, resource mapping not found for name: "prometheus-prometheus" namespace: "monitoring" from "": no matches for kind "Prometheus" in version "monitoring.coreos.com/v1"
ensure CRDs are installed first]
```

## Root Cause
The `kube-prometheus-stack` Helm chart requires **Custom Resource Definitions (CRDs)** to be installed **before** the chart itself can be deployed. The workflow was using `--set crds.enabled=false` which disables CRD installation by the chart, but the CRDs were never installed separately.

## Solution Applied

### 1. Install CRDs Before Chart Deployment
Added CRD installation commands before deploying the Prometheus stack:

```bash
# Install CRDs first (required for kube-prometheus-stack)
echo "Installing Prometheus CRDs..."
kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/crds/crd-alertmanagerconfigs.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/crds/crd-alertmanagers.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/crds/crd-podmonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/crds/crd-probes.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/crds/crd-prometheuses.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/crds/crd-prometheusrules.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/crds/crd-servicemonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/crds/crd-thanosrulers.yaml

# Wait for CRDs to be established
echo "Waiting for CRDs to be established..."
kubectl wait --for=condition=established --timeout=60s crd/alertmanagers.monitoring.coreos.com
kubectl wait --for=condition=established --timeout=60s crd/prometheuses.monitoring.coreos.com
```

### 2. Added CRD Cleanup on Destroy
Added CRD cleanup in the destroy workflow:

```bash
# Clean up Prometheus CRDs
kubectl delete crd alertmanagerconfigs.monitoring.coreos.com || true
kubectl delete crd alertmanagers.monitoring.coreos.com || true
kubectl delete crd podmonitors.monitoring.coreos.com || true
kubectl delete crd probes.monitoring.coreos.com || true
kubectl delete crd prometheuses.monitoring.coreos.com || true
kubectl delete crd prometheusrules.monitoring.coreos.com || true
kubectl delete crd servicemonitors.monitoring.coreos.com || true
kubectl delete crd thanosrulers.monitoring.coreos.com || true
```

## Files Modified
- `.github/workflows/terraform-apply.yaml` - Added CRD installation and cleanup

## Why This Happens
Many Helm charts that use custom Kubernetes resources require their CRDs to be installed first. The `kube-prometheus-stack` chart creates resources like:
- `Alertmanager` (monitoring.coreos.com/v1)
- `Prometheus` (monitoring.coreos.com/v1)
- `ServiceMonitor` (monitoring.coreos.com/v1)
- etc.

Without the CRDs, Kubernetes doesn't know how to handle these custom resources.

## Verification
After this fix, the Terraform pipeline should successfully:
1. Install all required CRDs
2. Wait for CRDs to be established
3. Deploy the kube-prometheus-stack chart
4. Create Prometheus, Alertmanager, and Grafana resources

## Next Steps
1. Push this fix to trigger a new Terraform pipeline run
2. Monitor the pipeline for successful Prometheus deployment
3. Verify that Grafana and Prometheus are accessible
4. Check that monitoring is working for the deployed applications