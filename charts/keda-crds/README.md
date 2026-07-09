# Arieotech KEDA CRDs Chart

CRD-only companion chart for [KEDA](https://keda.sh) 2.16.0. Installs all KEDA Custom Resource Definitions as Helm-managed resources so they can be versioned, upgraded, and rolled back independently of the KEDA operator.

## Why a separate CRD chart?

The official KEDA chart bundles CRDs inside the operator chart. This creates two problems in GitOps workflows:

1. **ArgoCD/Flux CRD drift** — Helm does not upgrade CRDs on `helm upgrade` by default. When the operator chart is upgraded, CRDs may become stale, causing schema validation failures.
2. **No independent CRD lifecycle** — You cannot upgrade CRDs without also upgrading the operator, which may not be desirable during rolling upgrades.

This chart (Arieotech fix for upstream [issue #5575](https://github.com/kedacore/charts/issues/5575)) separates CRDs so you can:
- Upgrade CRDs ahead of the operator upgrade
- Roll back CRDs independently
- Use `--force-conflicts` safely when CRDs change

## Install order

Always install `keda-crds` before `keda`:

```bash
helm repo add arieotech https://charts.arieotech.com
helm repo update

# 1. Install CRDs first
helm install keda-crds arieotech/keda-crds --namespace keda --create-namespace

# 2. Install operator
helm install keda arieotech/keda --namespace keda
```

An OCI registry is also available if you prefer it over the Helm repo:

```bash
helm install keda-crds oci://ghcr.io/arieotech/charts/keda-crds
helm install keda oci://ghcr.io/arieotech/charts/keda
```

## Upgrading CRDs

```bash
helm upgrade keda-crds arieotech/keda-crds --namespace keda
```

## ArgoCD integration

In your ArgoCD Application for the operator, set:

```yaml
spec:
  syncPolicy:
    syncOptions:
      - ServerSideApply=true
      - CreateNamespace=true
```

And deploy `keda-crds` as a separate Application with `sync-wave: "-1"` to ensure CRDs are applied before the operator.

## CRDs included

| CRD | Group | Scope |
|-----|-------|-------|
| ScaledObject | keda.sh/v1alpha1 | Namespaced |
| ScaledJob | keda.sh/v1alpha1 | Namespaced |
| TriggerAuthentication | keda.sh/v1alpha1 | Namespaced |
| ClusterTriggerAuthentication | keda.sh/v1alpha1 | Cluster |
| CloudEventSource | eventing.keda.sh/v1alpha1 | Namespaced |
| ClusterCloudEventSource | eventing.keda.sh/v1alpha1 | Cluster |
