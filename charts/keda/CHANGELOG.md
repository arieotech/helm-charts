# Changelog — arieotech/keda

All notable changes to this chart are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Chart versioning follows [Semantic Versioning](https://semver.org/).

---

## [0.1.0] — 2026-05-21

### Added
- Initial release of the Arieotech production-grade KEDA chart.
- KEDA **2.16.0** with all three components: operator, Metrics API Server, Admission Webhooks.
- **Arieotech fix for upstream issue #5943** — `operator.watchNamespace` value restricts the
  operator to specific namespaces, enabling safe multi-tenant cluster deployments.
- Companion `keda-crds` chart for GitOps-safe CRD management (Arieotech fix for upstream #5575).
- PSA restricted-mode compliance: `runAsNonRoot`, `readOnlyRootFilesystem`, `capabilities.drop: ALL`,
  `seccompProfile: RuntimeDefault` on all three containers.
- `values.schema.json` — full JSON Schema validation; rejects `latest` image tags.
- Per-component `image` blocks with `registry/repository:tag` or `@digest` support.
- Per-component `resources` blocks with requests and limits.
- `NetworkPolicy` for all three components, enabled by default.
- `PodDisruptionBudget` per component (operator, Metrics API Server, Admission Webhooks).
- `ServiceMonitor` included (via `arieotech.serviceMonitor` helper).
- `PrometheusRule` with `KedaOperatorDown`, `KedaMetricsApiServerDown`,
  `KedaScaledObjectError`, `KedaTriggerAuthenticationError` alerts.
- `APIService` registration for `v1beta1.external.metrics.k8s.io`.
- `ClusterRole` and `ClusterRoleBinding` for all three components, plus
  `system:auth-delegator` binding and `extension-apiserver-authentication-reader`
  RoleBinding for the Metrics API Server.
- `topologySpreadConstraints` default: spread across nodes with `DoNotSchedule`.
- SOC2 defaults: JSON-structured audit logging.
- DPDP defaults: `dpdp.arieotech.com/data-residency-region` pod annotation.
- Istio Ambient Mesh: `istio.io/dataplane-mode: ambient` label support and
  ztunnel port exclusion annotations.
- `ci/default-values.yaml` — single-replica CI install for `ct install`.
- `ci/ha-values.yaml` — two-replica HA profile with Prometheus Operator integration.
- `ci/soc2-values.yaml` — SOC2/DPDP-hardened CI profile.
- `topologySpreadConstraints` default now also spreads across `topology.kubernetes.io/zone`
  with `ScheduleAnyway`, matching the Arieotech baseline.
- `terminationGracePeriodSeconds: 30` on all three components, giving the operator time to
  finish in-flight `ScaledObject` reconciliations on shutdown.
- `secrets` value + `templates/secrets.yaml` — create arbitrary Secrets alongside the chart
  for `TriggerAuthentication` credentials (Redis, RabbitMQ, etc.).
- README expanded with a full values reference, a cert-manager `Certificate` example for
  webhook TLS, an ArgoCD sync-wave guide for `keda-crds` → `keda` ordering, and a
  troubleshooting section.

### Fixed
- Operator `NetworkPolicy` no longer ships a blanket `- {}` allow-all egress rule —
  it now stops at DNS + Kubernetes API, matching the "default-deny" behavior the
  README already documented. Add a rule per trigger source via `networkPolicy.extraEgress`.
- `metricsApiServer.apiService.insecureSkipTLSVerify` / `.caBundle` values added so the
  APIService's TLS verification skip is an explicit, documented opt-in/opt-out instead
  of a hardcoded `true`.
- `values.schema.json` now covers `terminationGracePeriodSeconds`, `secrets`, and
  `metricsApiServer.apiService` (previously undocumented in the schema).
- **Operator, Metrics API Server, and Admission Webhooks pods had no working Kubernetes
  API access.** All three set `automountServiceAccountToken: false` (and the ServiceAccount
  itself defaults to the same) with no explicit token volume to compensate — pods would
  have started with zero API credentials and crash-looped on first reconcile/leader-election
  attempt. Added `arieotech.serviceAccountTokenVolume` / `...VolumeMount` helpers to
  `arieotech-lib` and wired them into all three Deployments.
- Metrics API Server container passed `/adapter` as the first element of `args` instead of
  `command`, unlike the operator's `command: [/keda]` pattern. Depending on the image's
  ENTRYPOINT, this could run `/adapter` twice (once as entrypoint, once as its own first
  argument). Moved to `command: [/adapter]`, matching the operator.
- Removed `soc2.enforceTLS` and `dpdp.piiMasking` — neither was referenced by any template,
  so toggling them had no effect. `dpdp.dataResidency.enabled` now actually does something:
  it adds a `dpdp.arieotech.com/data-residency-region` pod annotation on all three
  components (previously declared in values/schema/README but never wired in).
- The "Allow Kubernetes API server" NetworkPolicy egress rule on all three components
  specified only `ports` with no `to:`, which in Kubernetes NetworkPolicy semantics allows
  HTTPS egress to **any destination** on 443/6443 — not just the API server, contradicting
  the chart's default-deny claims. Added `networkPolicy.kubeApiServerCIDR` so the rule can
  be pinned to an `ipBlock`; documented the port-only default's actual scope in the README
  and inline comments since a generic chart can't know the API server's address ahead of time.
- Corrected misleading comments in `clusterrole.yaml`/`clusterrolebinding.yaml` and the
  README's "Namespace-Scoped Installation" section: `operator.watchNamespace` limits what
  the operator's controller-runtime cache watches, but the ClusterRole/ClusterRoleBinding
  RBAC is always cluster-wide regardless of this setting — it is not a tenant-isolation
  or RBAC boundary.
- `templates/tests/test-connection.yaml`'s single-attempt `wget --spider` per endpoint was
  flaky against services that aren't immediately ready (especially in CI/kind). Added a
  retry loop (6 attempts, 10s apart), matching the keycloak chart's test-connection pattern.
- **`templates/pdb.yaml` and `templates/hpa.yaml` never rendered anything.** Both delegated
  to `arieotech-lib`'s single-component helpers, which gate on a top-level `.Values.replicaCount`
  (this chart only has per-component `operator.replicaCount` etc., so the PDB condition was
  always false) and target a Deployment named after the bare chart fullname (this chart's
  Deployments are suffixed, e.g. `-operator`, so the HPA would have pointed at a non-existent
  workload). Rewrote both as chart-local templates: a PDB per component, and an HPA scoped to
  the operator only, matching what `autoscaling.enabled`'s doc comment always said it did.
- **Operator ClusterRole was significantly over-privileged.** It granted full CRUD
  (`create`/`update`/`patch`/`delete`) cluster-wide on `configmaps`, `pods`, `secrets`,
  `serviceaccounts`, `services`, KEDA CRDs, and `leases` — upstream KEDA 2.16.0 only needs
  `get`/`list`/`watch` on those core resources cluster-wide, `get`/`list`/`patch`/`update`/`watch`
  on the CRDs it reconciles (it doesn't create/delete ScaledObjects/ScaledJobs itself), and
  scopes write access to `secrets`/`leases` to its own release namespace via a separate `Role`.
  Rewrote the ClusterRole to match upstream's actual `config/rbac/role.yaml` verb-for-verb, and
  added the namespace-scoped `Role`/`RoleBinding` for `secrets`/`leases` writes.
- NetworkPolicy ingress rules for kube-aggregator→Metrics-API-Server and
  kube-apiserver→webhook traffic had no `from:` selector, so — like the egress rules
  fixed above — they allowed inbound from any source on those ports despite comments
  implying otherwise. Both now use `networkPolicy.kubeApiServerCIDR` (the same value
  used for egress) to restrict the source when set. Corrected the remaining
  kubelet-health-check and Prometheus-scrape ingress rules' comments to state plainly
  that they're port-only — Kubernetes NetworkPolicy has no portable selector for
  either kubelet or an arbitrary scraper.
- Removed `autoscaling.kind` — the operator is the only workload the HPA can target
  and is always rendered as a Deployment, so `StatefulSet` in the schema's enum could
  never correspond to a real object; the HPA's `scaleTargetRef.kind` is now hardcoded.
  Fixed the HPA's `minReplicas`/`maxReplicas` fallback (1/3) to match values.yaml's
  actual documented defaults (2/5). Added the missing
  `autoscaling.targetMemoryUtilizationPercentage` to `values.schema.json` and
  documented it (the template already supported it).
- **Metrics API Server and Admission Webhooks containers crash-looped on real clusters**
  (`exec: "/adapter": stat /adapter: no such file or directory`) — an earlier fix moved
  `/adapter`/`/webhooks` from `args` into `command`, but those binary paths were wrong.
  Verified the actual entrypoints against the published `ghcr.io/kedacore/keda-metrics-apiserver:2.16.0`
  and `ghcr.io/kedacore/keda-admission-webhooks:2.16.0` image configs (and the upstream
  `Dockerfile.adapter`/`Dockerfile.webhooks` at the `v2.16.0` tag): the real paths are
  `/keda-adapter` and `/keda-admission-webhooks`. `ct install` caught this because it
  actually runs the containers — `helm template`/`kubectl apply --dry-run` cannot, since
  neither validates that a container's command actually exists in the image.
- **Added the missing `ValidatingWebhookConfiguration`.** The admission-webhooks
  Deployment/Service/RBAC all existed, but nothing actually registered the webhook with
  the API server — the pods ran and served traffic that never arrived. Added
  `templates/validatingwebhookconfiguration.yaml` matching upstream KEDA's
  `config/webhooks/validation_webhooks.yaml` (6 validating webhooks: ScaledObject,
  ScaledJob, TriggerAuthentication, ClusterTriggerAuthentication, CloudEventSource,
  ClusterCloudEventSource), plus `admissionWebhooks.caBundle` /
  `.certManagerCertificate` values so the API server can trust the webhook's TLS cert.
- **All three components shared one ServiceAccount bound to three different
  ClusterRoles**, giving every pod the union of all three components' RBAC — including
  the operator's namespace-scoped Secrets/Leases write access leaking into the
  admission-webhook and metrics-apiserver pods, and vice versa. Split into three
  per-component ServiceAccounts (`keda.operatorServiceAccountName`,
  `.metricsServiceAccountName`, `.webhooksServiceAccountName`), each bound only to its
  own component's Cluster/RoleBindings.
- `pdb.maxUnavailable` used a truthy `{{ if }}` check, so an explicit `0` (a valid PDB
  value, allowed by the schema) was treated as unset and silently fell back to
  `minAvailable`. Switched to `hasKey` so `0` is honored.
- Corrected the SOC2 compliance section's claim that "all KEDA components write logs
  in JSON format" — the Metrics API Server uses klog's plain-text format
  (`--logtostderr`), not JSON; only the operator and admission webhooks are JSON.
- **Operator and Metrics API Server crash-looped on every real cluster**
  (`"msg"="failed to get watch namespace" "error"="WATCH_NAMESPACE must be set"`).
  Both binaries call `kedautil.GetWatchNamespaces()` (`pkg/util/watch.go` in
  kedacore/keda), which does `os.LookupEnv("WATCH_NAMESPACE")` and exits fatally if the
  variable isn't present at all — even set to `""`. The chart instead passed
  `--watch-namespace=<value>` as a CLI flag, which isn't a real flag on either binary
  (checked every `pflag.*Var` registration in `cmd/operator/main.go` — no
  `watch-namespace` flag exists) and would have hard-failed with "unknown flag" the
  moment anyone set `operator.watchNamespace` to a non-empty value, on top of never
  fixing the always-fatal missing-env-var case. Removed the fake flag; added a
  `WATCH_NAMESPACE` env var (from `operator.watchNamespace`) to both deployments.
- Removed `serviceAccount.automountServiceAccountToken` — every ServiceAccount and pod
  spec hardcodes `automountServiceAccountToken: false` (required for the projected
  token volume design to work), so the value had no effect if a user set it to `true`.
  Added `additionalProperties: false` to the schema's `serviceAccount` object so
  setting it now fails `helm lint`/`helm install` with a clear error instead of
  silently doing nothing.
