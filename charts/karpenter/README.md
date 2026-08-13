# karpenter

Production-grade [Karpenter](https://karpenter.sh) **1.14.0** (LTS) chart for AWS/EKS
node autoscaling — security-hardened, GitOps-safe, and fully schema-validated.

> **Ships no CRDs by design.** Install the [`karpenter-crds`](../karpenter-crds) chart
> first. Bundling CRDs in the controller chart is what makes ArgoCD report perpetual
> drift (upstream [#6847](https://github.com/aws/karpenter-provider-aws/issues/6847));
> separating them is the fix.

## What this chart fixes / adds

| Area | This chart |
|------|-----------|
| **ArgoCD CRD drift (#6847)** | CRDs live in a separate, versioned chart — no embedded static CRDs |
| **Security** | PSA restricted: non-root, read-only rootfs, drop ALL caps, seccomp RuntimeDefault |
| **RBAC** | Least-privilege ClusterRole + namespaced leases/dns Roles (no cluster-admin) |
| **NetworkPolicy** | Enabled by default — DNS, API server, and AWS API egress only |
| **Validation** | Full `values.schema.json`; `latest` image tags rejected |
| **Observability** | ServiceMonitor + PrometheusRule (down / reconcile-error / cloud-provider-error alerts) |
| **Correct for v1** | No webhook server (removed in v1); `FEATURE_GATES` env; `drift` is GA, not a gate |
| **Compliance** | SOC2 JSON stdout logging, DPDP data-residency annotation |
| **Mesh** | Istio Ambient Mesh labels + ztunnel port exclusion |

## Prerequisites

- An **EKS** cluster (Karpenter's AWS provider requires a real AWS account).
- The [`karpenter-crds`](../karpenter-crds) chart installed.
- An IAM role for the controller, wired via **IRSA** or **EKS Pod Identity**.
- Recommended: an SQS interruption queue for graceful Spot handling.

## Install

```bash
# 1. CRDs first (separate chart)
helm install karpenter-crds arieotech/karpenter-crds -n kube-system

# 2. Controller
helm install karpenter arieotech/karpenter -n kube-system \
  --set settings.clusterName=my-cluster \
  --set settings.interruptionQueue=my-cluster-interruptions \
  --set-json 'serviceAccount.annotations={"eks.amazonaws.com/role-arn":"arn:aws:iam::123456789012:role/KarpenterController"}'
```

`settings.clusterName` is **required** — the controller (and a Helm `required` guard)
will refuse to start without it. On EKS, `settings.clusterEndpoint` is auto-discovered
if left empty.

Then create a `NodePool` + `EC2NodeClass` — see the
[Karpenter getting-started guide](https://karpenter.sh/docs/getting-started/).

## Key values

| Key | Default | Description |
|-----|---------|-------------|
| `image.tag` | `1.14.0` | Controller image tag (`digest` wins if set; `latest` is rejected by the schema). |
| `replicaCount` | `2` | Leader-elected; one active, one standby. |
| `settings.clusterName` | `""` | **Required.** EKS cluster name. |
| `settings.clusterEndpoint` | `""` | EKS API endpoint; auto-discovered on EKS when empty. |
| `settings.interruptionQueue` | `""` | SQS queue for Spot interruption/rebalance events. |
| `settings.featureGates` | see values | PascalCase Karpenter feature gates → bool. |
| `serviceAccount.annotations` | `{}` | Put your IRSA / Pod Identity IAM role ARN here. |
| `rbac.dns.namespace` | `kube-system` | Namespace of the kube-dns/CoreDNS Service. |
| `networkPolicy.enabled` | `true` | Deny-by-default with DNS/API/AWS egress allow-list. |
| `networkPolicy.kubeApiServerCIDR` | `""` | Pin API-server egress to a CIDR. |
| `networkPolicy.awsApiEgress` | `true` | Allow 443 egress for AWS API calls. |
| `pdb.maxUnavailable` | `1` | PodDisruptionBudget (only rendered when `replicaCount > 1`). |
| `metrics.serviceMonitor.enabled` | `false` | Prometheus Operator ServiceMonitor. |
| `metrics.prometheusRule.enabled` | `false` | Bundled alerting rules. |
| `istio.ambient.enabled` | `false` | Join the Istio Ambient dataplane. |

See [`values.yaml`](values.yaml) for the complete, commented set.

## Ports (Karpenter v1)

| Port | Purpose |
|------|---------|
| `8080` | Prometheus metrics (`/metrics`) |
| `8081` | Health / readiness (`/healthz`, `/readyz`) |

There is **no** `8443` webhook port — Karpenter removed its admission webhooks in v1;
CR validation is enforced by CEL rules embedded in the CRDs.

## Production checklist

- [x] PSA restricted-mode compatible; no `latest` tags.
- [x] NetworkPolicy enabled by default.
- [x] Least-privilege RBAC (no `cluster-admin`, namespaced write scope for leases).
- [x] `values.schema.json`, resource requests/limits, PDB, ServiceMonitor, PrometheusRule.
- [ ] Install `karpenter-crds` **first** and keep it ≥ this chart's `appVersion`.
- [ ] Provide an IRSA / Pod Identity role via `serviceAccount.annotations`.
- [ ] Set `settings.interruptionQueue` in production for graceful Spot handling.
- [ ] Keep the controller off Karpenter-managed nodes (default affinity does this).

## Compatibility

- Karpenter **1.14.0** (LTS, supported through July 2027).
- Kubernetes ≥ 1.25 (`KUBERNETES_MIN_VERSION` is set to `1.19.0-0` for the controller's
  own gate, but PSA restricted + the CRD schemas target modern clusters).

## License

Apache 2.0 — see [LICENSE](../../LICENSE).
