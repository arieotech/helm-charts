# Changelog — karpenter

All notable changes to this chart are documented here.

## 0.1.0

- Initial release — production-grade **Karpenter 1.14.0** (LTS) controller for AWS/EKS.
- **GitOps-safe CRD separation**: this chart ships **no** CRDs. Install the
  [`karpenter-crds`](../karpenter-crds) chart first. This is the fix for ArgoCD CRD
  drift, upstream [#6847](https://github.com/aws/karpenter-provider-aws/issues/6847).
- Correct for Karpenter v1: **no webhook server** (validation is CEL-in-CRD), ports are
  metrics `8080` / health `8081` only, and `FEATURE_GATES` is a single comma-separated
  env (`drift` is GA/always-on and is not a gate).
- **PSA restricted-mode** pod/container security contexts (`runAsNonRoot`,
  `readOnlyRootFilesystem`, drop ALL caps, `seccompProfile: RuntimeDefault`).
- **Least-privilege RBAC**: controller ClusterRole matching upstream 1.14.0, plus a
  namespaced leader-election `leases` Role and a `kube-dns` read Role in `kube-system`.
- **NetworkPolicy enabled by default** — DNS, Kubernetes API server (optionally
  CIDR-pinned), and AWS API (443) egress; metrics/health ingress.
- **Full `values.schema.json`** — rejects `latest` image tags, validates every value.
- PodDisruptionBudget, ServiceMonitor, and PrometheusRule (KarpenterDown,
  KarpenterReconcileErrors, KarpenterCloudProviderErrors).
- **Istio Ambient Mesh** support (dataplane label + ztunnel port exclusion).
- **SOC2** structured-JSON stdout logging and **DPDP** data-residency annotation defaults.
- IRSA / EKS Pod Identity ready via `serviceAccount.annotations`.
