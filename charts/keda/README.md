# arieotech/keda

Production-grade Helm chart for [KEDA](https://keda.sh) (Kubernetes Event-Driven Autoscaling) **2.16.0**.

Fixes two critical upstream gaps:

| Upstream issue | Arieotech fix |
|---|---|
| [#5943](https://github.com/kedacore/charts/issues/5943) — Namespace-scoped RBAC broken | `operator.watchNamespace` value restricts the operator to specific namespaces |
| [#5575](https://github.com/kedacore/charts/issues/5575) — No CRD separation chart | Companion [`keda-crds`](../keda-crds/) chart manages CRDs independently |

## Components

| Component | Image | Purpose |
|---|---|---|
| `keda-operator` | `ghcr.io/kedacore/keda:2.16.0` | Watches ScaledObjects, manages HPA |
| `keda-metrics-apiserver` | `ghcr.io/kedacore/keda-metrics-apiserver:2.16.0` | Aggregated API for external metrics |
| `keda-admission-webhooks` | `ghcr.io/kedacore/keda-admission-webhooks:2.16.0` | Validates KEDA custom resources |

## Prerequisites

- Kubernetes 1.27+
- Helm 3.12+
- `keda-crds` chart installed first (see below)
- **Only one release of this chart per cluster.** The Metrics API Server registers a
  cluster-scoped `APIService` (`v1beta1.external.metrics.k8s.io`) with a fixed name —
  a second release anywhere in the cluster would collide on that same object. This
  matches upstream KEDA's own single-instance-per-cluster design; it isn't something
  `operator.watchNamespace` changes, since that only scopes what the operator watches,
  not the cluster-scoped resources it registers.

No cert-manager or other TLS provisioning is required — see
[TLS Certificates](#tls-certificates) for how that's handled.

## Quick Start

```bash
# Step 1 — Install CRDs separately (GitOps/ArgoCD safe)
helm upgrade --install keda-crds arieotech/keda-crds \
  --namespace keda --create-namespace

# Step 2 — Install the operator
helm upgrade --install keda arieotech/keda \
  --namespace keda --create-namespace \
  --values my-values.yaml
```

## Namespace-Scoped Installation (Arieotech fix for #5943)

To restrict the KEDA operator to specific namespaces:

```yaml
operator:
  watchNamespace: "production,staging"
```

With this setting, KEDA only *reconciles* `ScaledObject` and `ScaledJob` resources in the
listed namespaces. This is a reconciliation-scope control, not an RBAC boundary — the
operator's ClusterRole/ClusterRoleBinding still grant cluster-wide permissions regardless
of this setting, since Kubernetes RBAC has no per-namespace restriction mechanism for a
ClusterRoleBinding. Use it to avoid the operator acting on ScaledObjects outside its
intended scope, not as a tenant-isolation security control.

## Values Reference

| Key | Type | Default | Description |
|---|---|---|---|
| `global.imagePullSecrets` | list | `[]` | Image pull secrets applied to all components |
| `operator.image.tag` | string | `"2.16.0"` | Operator image tag. `latest` is rejected. |
| `operator.image.digest` | string | `""` | Pin operator image by digest instead of tag |
| `operator.replicaCount` | int | `2` | Number of operator replicas |
| `operator.resources` | object | `100m/128Mi` req, `256Mi` limit | Operator container resources |
| `operator.watchNamespace` | string | `""` | Comma-separated namespaces to watch. Empty = cluster-wide |
| `operator.logLevel` | string | `"info"` | Log level: `debug`, `info`, `error` |
| `operator.logEncoder` | string | `"json"` | Log format: `json`, `console` |
| `operator.logTimeFormat` | string | `"rfc3339"` | Log timestamp encoding |
| `operator.extraEnv` | list | `[]` | Extra env vars on the operator container |
| `metricsApiServer.replicaCount` | int | `2` | Metrics API Server replicas |
| `metricsApiServer.resources` | object | `100m/128Mi` req, `256Mi` limit | Metrics API Server container resources |
| `metricsApiServer.port` | int | `6443` | HTTPS port for the aggregated API |
| `metricsApiServer.logLevel` | string | `"0"` | glog verbosity level |
| `admissionWebhooks.enabled` | bool | `false` | Deploy admission webhooks — TLS is provisioned automatically by the operator's cert rotator, see [TLS Certificates](#tls-certificates); defaults to `false` pending live CI confirmation of that mechanism |
| `admissionWebhooks.replicaCount` | int | `2` | Admission webhook replicas |
| `admissionWebhooks.resources` | object | `50m/64Mi` req, `128Mi` limit | Admission webhook container resources |
| `admissionWebhooks.port` | int | `9443` | Webhook HTTPS port |
| `serviceAccount.create` | bool | `true` | Create a ServiceAccount |
| `podSecurityContext` / `securityContext` | object | PSA restricted | Pod and container security contexts |
| `terminationGracePeriodSeconds` | int | `30` | Grace period for in-flight ScaledObject reconciliations on shutdown |
| `topologySpreadConstraints` | list | hostname + zone | Spread pods across nodes and AZs |
| `networkPolicy.enabled` | bool | `true` | Deploy NetworkPolicy resources |
| `networkPolicy.kubeApiServerCIDR` | string | `""` | Restrict the API server egress rule to this CIDR (e.g. `"10.0.0.1/32"`); unset allows HTTPS egress to any destination on 443/6443 — see [NetworkPolicy](#networkpolicy) |
| `networkPolicy.extraIngress` / `extraEgress` | list | `[]` | Additional rules appended to the default allow-list |
| `pdb.enabled` | bool | `true` | Deploy PodDisruptionBudget |
| `pdb.minAvailable` | int | `1` | Minimum available pods per component |
| `autoscaling.enabled` | bool | `false` | HPA for the operator Deployment only (uncommon, provided for completeness) |
| `autoscaling.minReplicas` / `maxReplicas` | int | `2` / `5` | HPA replica bounds |
| `autoscaling.targetCPUUtilizationPercentage` | int | `70` | CPU target; omit to disable the CPU metric |
| `autoscaling.targetMemoryUtilizationPercentage` | int | unset | Optional memory target metric, disabled unless set |
| `metrics.enabled` | bool | `true` | Expose Prometheus metrics |
| `metrics.serviceMonitor.enabled` | bool | `false` | Create ServiceMonitor (requires Prometheus Operator) |
| `metrics.prometheusRule.enabled` | bool | `false` | Create PrometheusRule with alert rules |
| `istio.ambient.enabled` | bool | `false` | Add Istio Ambient dataplane labels |
| `istio.ambient.excludedPorts` | list | `[]` | Ports excluded from ztunnel capture |
| `soc2.auditLogging.enabled` | bool | `true` | JSON-structured audit logging |
| `dpdp.dataResidency.enabled` | bool | `false` | Add the `dpdp.arieotech.com/data-residency-region` pod annotation |
| `dpdp.dataResidency.region` | string | `""` | Region value for the data-residency annotation, e.g. `"in-mumbai"` |
| `secrets` | object | `{}` | Arbitrary Secrets created alongside the chart — see [TriggerAuthentication credentials](#triggerauthentication-credentials) |
| `extraVolumes` / `extraVolumeMounts` | list | `[]` | Extra volumes mounted on every component |
| `initContainers` / `sidecars` | list | `[]` | Extra init/sidecar containers on the operator pod |

### TriggerAuthentication credentials

`secrets` creates arbitrary `Secret` resources named `<fullname>-<key>`, where
`<fullname>` follows the standard Helm fullname convention (a release named `keda`
produces just `keda`, not `keda-keda`). Useful for `TriggerAuthentication` credentials
(Redis passwords, RabbitMQ connection strings, etc.) without hand-rolling a separate
`Secret` manifest:

```yaml
secrets:
  redis-trigger-auth:
    stringData:
      password: "changeme"
  rabbitmq-trigger-auth:
    type: Opaque
    stringData:
      connectionString: "amqp://user:pass@rabbitmq:5672/vhost"
```

Reference the generated Secret name (`keda-redis-trigger-auth` for a release named
`keda`) from your own `TriggerAuthentication` resources.

## TLS Certificates

Unlike many operator charts, you don't need cert-manager or any manual TLS
provisioning here. The operator runs with cert rotation enabled by default
(`--enable-cert-rotation`, via [`open-policy-agent/cert-controller`](https://github.com/open-policy-agent/cert-controller)):
it generates a CA and cert bundle, stores it in a `<fullname>-certs` Secret in the
release namespace, and automatically patches the resulting `caBundle` onto both the
`ValidatingWebhookConfiguration` and the `APIService`. The Metrics API Server and (if
enabled) Admission Webhooks mount that same Secret read-only at `/certs`.

The `<fullname>-certs` Secret is `optional: true` on its consumers, since on first
install the operator needs a moment to create it. The Metrics API Server and (if
enabled) Admission Webhooks Deployments each run a `wait-for-certs` initContainer
that polls for the cert files before starting the main container, so they wait
rather than crash-loop during that window — no action needed.

If you run your own PKI and want to bypass this entirely, you'd need to remove
`--enable-cert-rotation` from `templates/deployment-operator.yaml` and wire your own
cert-manager `Certificate` + `caBundle` back in — there's currently no values-driven
toggle for this, since the chart doesn't yet have a values profile that exercises it.

## NetworkPolicy

Every component's egress rules stop at DNS and an "allow the Kubernetes API server" rule
on 443/6443 — but that API server rule is **port-only by default**, not destination-restricted.
Kubernetes NetworkPolicy has no generic pod or namespace selector for the API server (it
typically runs outside the pod network, e.g. on control-plane nodes or behind a cloud LB),
so a rule with only `ports` and no `to:` matches **any destination** on that port. In
practice this means HTTPS egress to any host on 443/6443 is allowed out of the box, not
just to the API server.

To actually restrict it, set `networkPolicy.kubeApiServerCIDR` to your API server's IP:

```bash
kubectl get endpoints kubernetes -n default -o jsonpath='{.subsets[0].addresses[*].ip}'
```

```yaml
networkPolicy:
  kubeApiServerCIDR: "10.0.0.1/32"
```

Once set, that rule becomes `to: [{ ipBlock: { cidr: ... } }]` and no longer permits
arbitrary HTTPS egress. This isn't set by default because the API server's address is
cluster-specific and not knowable ahead of time by a generic chart.

**Do not set `kubeApiServerCIDR` if you rely on this chart's default health checks
for the Metrics API Server.** Its liveness/readiness probes hit the same HTTPS port
as kube-aggregator traffic (there's no separate health port on that binary), and
`kubeApiServerCIDR` restricts *ingress* on that port too — which also blocks
kubelet's probe traffic, since kubelet has no selectable identity NetworkPolicy can
carve an exception out for. There's no NetworkPolicy-only way to allow both "the API
server from a specific CIDR" and "kubelet from the node" on the same port at once.

## Deploying with ArgoCD

`keda-crds` must be installed (and healthy) before `keda`, since the operator and
webhooks depend on the CRDs existing at startup. When managing both charts as ArgoCD
`Application` resources, set sync waves so CRDs land first:

```yaml
# keda-crds Application
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
---
# keda Application
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
```

If using an ApplicationSet or a single App-of-Apps, apply the same `sync-wave`
annotations to the generated Applications. `keda-crds` ships
`helm.sh/resource-policy: keep` on every CRD, so ArgoCD pruning or `helm uninstall`
never deletes CRDs (and the ScaledObjects/ScaledJobs they back) by accident.

## Troubleshooting

**Operator crash-looping with `no matches for kind "ScaledObject"`:** The `keda-crds`
chart was not installed, or was installed after `keda`. Install/sync `keda-crds` first
and confirm with `kubectl get crd | grep keda.sh`.

**Admission webhook (or operator, or Metrics API Server) pods stuck `CrashLoopBackOff`
on startup with a cert-related error:** The `<fullname>-certs` Secret the operator's
cert rotator manages doesn't exist yet — normal briefly on first install (see
[TLS Certificates](#tls-certificates)); kubelet retries automatically. If it persists,
check the operator's own logs first — it owns creating this Secret. You can
temporarily set `admissionWebhooks.enabled: false` to unblock ScaledObject changes
while investigating.

**HPA not scaling despite ScaledObject present:** Confirm the metrics API server is
registered: `kubectl get apiservice v1beta1.external.metrics.k8s.io`. If it shows
`False` under `AVAILABLE`, check `metricsApiServer` pod logs and that
`auth-delegator`/`extension-apiserver-authentication-reader` RoleBindings exist.

**`operator.watchNamespace` set but scaling still happens everywhere:** The value is
comma-separated with no spaces (e.g. `"production,staging"`, not `"production, staging"`).
Restart the operator pods after changing this value — it is read at process start.

**NetworkPolicy blocking scaler connectivity:** `networkPolicy.enabled=true` ships a
default-deny egress policy for everything *except* DNS and HTTPS to 443/6443 (see
[NetworkPolicy](#networkpolicy) for why that HTTPS rule is broader than "API server only"
by default). For non-HTTPS trigger sources (e.g. plain RabbitMQ/Kafka ports), add a rule
via `networkPolicy.extraEgress`.

## Production Checklist

- [ ] `keda-crds` chart installed and version matches `operator.image.tag`
- [ ] `operator.watchNamespace` set for multi-tenant clusters
- [ ] `networkPolicy.enabled=true` (default)
- [ ] `pdb.enabled=true` (default)
- [ ] `metrics.serviceMonitor.enabled=true` if using Prometheus Operator
- [ ] `metrics.prometheusRule.enabled=true` for alert rules
- [ ] `admissionWebhooks.enabled=true` (default `false`) once you've confirmed the operator's cert rotator is provisioning `<fullname>-certs` correctly — see [TLS Certificates](#tls-certificates)
- [ ] `soc2.auditLogging.enabled=true` (default) for audit log compliance
- [ ] Image digest pinning: set `operator.image.digest` / `metricsApiServer.image.digest` / `admissionWebhooks.image.digest`
- [ ] `replicaCount >= 2` for all components (default)

## SOC2 Compliance

Structured JSON audit logging is enabled by default (`soc2.auditLogging.enabled=true`).
The operator and admission webhooks write JSON logs to stdout (`operator.logEncoder`,
default `json`). The Metrics API Server uses klog's plain-text format (`--logtostderr`) —
it doesn't have a JSON logging flag wired up in this chart. Route what's JSON-structured
to your SIEM with a log aggregation agent (Fluent Bit, Vector, etc.); the Metrics API
Server's plain-text lines will need a text/regex parser instead of a JSON one.

## DPDP Compliance

KEDA itself does not process PII, so there is no masking toggle to configure. Setting
`dpdp.dataResidency.enabled: true` adds a `dpdp.arieotech.com/data-residency-region: "<region>"`
annotation to every pod, which your policy enforcement layer (OPA/Gatekeeper) can key off of.

## Istio Ambient Mesh

```yaml
istio:
  ambient:
    enabled: true
    excludedPorts:
      - 9443   # exclude webhook port from ztunnel (handled by webhook TLS directly)
```

## Upgrading

To upgrade KEDA, upgrade the `keda-crds` chart first, then this chart. The CRD chart is
designed to be safely re-applied — it uses `helm.sh/resource-policy: keep` annotations to
prevent CRD deletion on `helm uninstall`.

## Uninstalling

```bash
helm uninstall keda -n keda
# CRDs are managed separately — uninstall them only when KEDA is fully removed:
helm uninstall keda-crds -n keda
```

## Source & License

- Chart source: [github.com/arieotech/helm-charts](https://github.com/arieotech/helm-charts)
- License: Apache 2.0
- KEDA upstream: [github.com/kedacore/keda](https://github.com/kedacore/keda)
