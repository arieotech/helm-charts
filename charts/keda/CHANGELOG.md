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
- `PodDisruptionBudget` included (via `arieotech.pdb` helper).
- `ServiceMonitor` included (via `arieotech.serviceMonitor` helper).
- `PrometheusRule` with `KedaOperatorDown`, `KedaMetricsApiServerDown`,
  `KedaScaledObjectError`, `KedaTriggerAuthenticationError` alerts.
- `APIService` registration for `v1beta1.external.metrics.k8s.io`.
- `ClusterRole` and `ClusterRoleBinding` for all three components, plus
  `system:auth-delegator` binding and `extension-apiserver-authentication-reader`
  RoleBinding for the Metrics API Server.
- `topologySpreadConstraints` default: spread across nodes with `DoNotSchedule`.
- SOC2 defaults: JSON-structured audit logging, TLS enforcement flag.
- DPDP defaults: PII masking and data residency stubs.
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
