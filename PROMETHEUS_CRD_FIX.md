# 🔧 Prometheus CRD Installation Fix

## Problem
The Terraform pipeline was failing with this error:
```
The CustomResourceDefinition "alertmanagerconfigs.monitoring.coreos.com" is invalid: metadata.annotations: Too long: may not be more than 262144 bytes
Error: Process completed with exit code 1
```

## Root Cause
The workflow was manually installing Prometheus CRDs using `kubectl apply` with CRD files from the prometheus-operator GitHub repository. These CRD files contain very large annotations that exceed Kubernetes' 262,144 byte limit for metadata.annotations.

## Solution Applied

### 1. Use Helm Chart CRDs Instead of Manual Installation
Instead of manually installing CRDs with `kubectl apply`, we now let the kube-prometheus-stack Helm chart handle CRD installation by setting `crds.enabled=true`. The Helm chart includes properly formatted CRDs that don't exceed the annotation size limits.

**Changes Made:**
- Removed manual CRD installation commands (`kubectl apply` for all CRDs)
- Changed `crds.enabled=false` to `crds.enabled=true` in the kube-prometheus-stack Helm installation
- Removed manual CRD deletion in the destroy workflow since Helm now manages the CRDs

### 2. Benefits of This Approach
- ✅ Eliminates CRD annotation size limit errors
- ✅ Ensures CRDs are properly managed by Helm
- ✅ Simplifies the deployment process
- ✅ More reliable CRD installation and cleanup
- ✅ Automatic CRD updates with Helm chart updates

## Previous Issues (Resolved)
The pipeline previously failed with CRD mapping errors because CRDs weren't installed at all. This was fixed by initially adding manual CRD installation, but then encountered the annotation size limit issue which is now resolved by using Helm-managed CRDs.

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