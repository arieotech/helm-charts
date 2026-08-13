# karpenter-crds

CRD-only companion chart for [Karpenter](https://karpenter.sh) **1.14.0**. Installs the
Karpenter CustomResourceDefinitions as **Helm-managed** resources so they can be
versioned, upgraded, and rolled back independently of the Karpenter controller.

Install this chart **first**, then install the [`karpenter`](../karpenter) controller
chart — which deliberately ships no CRDs of its own, so there is nothing to toggle off.

## Why a separate CRD chart?

Karpenter's own controller chart embeds its CRDs as static files under `crds/`. Helm
never templates or upgrades files in that directory, and their contents don't reflect
Helm values — which makes ArgoCD (and other GitOps tools) continuously report drift and
makes CRD upgrades a manual, error-prone step. This is upstream issue
[#6847](https://github.com/aws/karpenter-provider-aws/issues/6847).

Splitting the CRDs into their own chart:

- **Fixes ArgoCD drift** — CRDs are ordinary templated manifests ArgoCD can reconcile.
- **Makes CRD upgrades explicit** — bump this chart's version to roll CRDs forward
  (or back) on their own schedule, separate from the controller rollout.
- **Protects live nodes** — `helm.sh/resource-policy: keep` (default) stops
  `helm uninstall` from deleting the CRDs, which would cascade to deleting every live
  `NodePool`/`NodeClaim` and deprovision the nodes they manage.

## CRDs installed

| CRD | Group / Version | Scope |
|-----|-----------------|-------|
| `NodePool` | `karpenter.sh/v1` | Cluster |
| `NodeClaim` | `karpenter.sh/v1` | Cluster |
| `NodeOverlay` | `karpenter.sh/v1alpha1` | Cluster |
| `EC2NodeClass` | `karpenter.k8s.aws/v1` | Cluster |
| `CapacityBuffer` | `autoscaling.x-k8s.io/v1beta1` | Namespaced |

CRD schemas are vendored **verbatim** from `aws/karpenter-provider-aws` at tag
`v1.14.0` — only `metadata.labels` and `metadata.annotations` are templated.

## Install

```bash
helm install karpenter-crds arieotech/karpenter-crds \
  --namespace kube-system
```

### ArgoCD

Add a sync-wave so the CRDs apply before any chart that references them:

```yaml
commonAnnotations:
  argocd.argoproj.io/sync-wave: "-1"
```

## Values

| Key | Default | Description |
|-----|---------|-------------|
| `keepCRDs` | `true` | Stamp `helm.sh/resource-policy: keep` on every CRD so `helm uninstall` doesn't delete them (or the live resources they back). Set `false` only on ephemeral/CI clusters. |
| `commonLabels` | `{}` | Extra labels applied to all CRDs. |
| `commonAnnotations` | `{}` | Extra annotations applied to all CRDs. |

## Upgrading CRDs

Karpenter requires CRDs to be at or ahead of the controller version. Upgrade order:

```bash
# 1. CRDs first
helm upgrade karpenter-crds arieotech/karpenter-crds -n kube-system
# 2. then the controller
helm upgrade karpenter arieotech/karpenter -n kube-system
```

## Production checklist

- [x] CRD schemas vendored verbatim from a pinned upstream tag (`v1.14.0`).
- [x] `helm.sh/resource-policy: keep` on by default — safe teardown.
- [x] GitOps/ArgoCD-safe (templated, reconcilable, sync-wave friendly).
- [ ] Install this chart **before** the controller chart.
- [ ] Keep this chart's version **≥** the controller chart's `appVersion`.

## License

Apache 2.0 — see [LICENSE](../../LICENSE).
