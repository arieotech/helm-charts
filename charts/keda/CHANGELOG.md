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
- README expanded with a full values reference, an ArgoCD sync-wave guide for
  `keda-crds` → `keda` ordering, and a troubleshooting section.

### Fixed
- Operator `NetworkPolicy` no longer ships a blanket `- {}` allow-all egress rule —
  it now stops at DNS + Kubernetes API, matching the "default-deny" behavior the
  README already documented. Add a rule per trigger source via `networkPolicy.extraEgress`.
- `metricsApiServer.apiService.insecureSkipTLSVerify` value added so the APIService's
  TLS verification skip is an explicit, documented opt-in/opt-out instead of a
  hardcoded `true`. (A `.caBundle` value was added alongside it here, then removed
  later in this same changelog once cert-rotation made it dead — see below.)
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
  ClusterCloudEventSource). (This originally shipped alongside `admissionWebhooks.caBundle`
  / `.certManagerCertificate` values for the API server to trust the webhook's TLS cert —
  both were removed later in this same changelog once cert-rotation made them dead.)
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
- `metadata.annotations` on all three Deployments' pod templates rendered
  unconditionally, so with the defaults (no Istio ambient, no DPDP data residency, no
  `podAnnotations`) it rendered as `annotations:` with nothing after it — YAML null
  where Kubernetes expects a map. The API server tolerated it in testing, but it's not
  something to rely on. Added `keda.podAnnotations` (in `_helpers.tpl`), which only
  emits the `annotations:` key when at least one of the three sources has content;
  verified against each source individually, all three combined, and a multi-key
  `podAnnotations` value (to make sure a helper bug didn't just move the indentation
  problem into the multi-line case).
- **Operator and Admission Webhooks health/metrics ports were wrong, and the
  operator's Prometheus toggle caused a port collision that would crash it whenever
  `metrics.enabled=true`.** Verified against `cmd/operator/main.go`,
  `cmd/webhooks/main.go`, and `cmd/adapter/main.go` (all `kedacore/keda @ v2.16.0`),
  plus KEDA's own upstream `config/metrics-server/deployment.yaml`:
  - Operator: `--metrics-bind-address=:9666` (toggled by `metrics.enabled`) collided
    with `--metrics-service-bind-address`'s own default of `:9666` — the gRPC channel
    the Metrics API Server uses to resolve external metrics, required regardless of
    `metrics.enabled` and completely unrelated to Prometheus. Whenever `metrics.enabled`
    was `true`, the operator would crash with a bind-address-in-use error. Replaced with
    the real toggle flag, `--enable-prometheus-metrics=false`. Also, no
    `--health-probe-bind-address` flag was ever set, so probes targeting containerPort
    `8080` were checking a port the binary was never actually listening on
    (`--health-probe-bind-address` defaults to `:8081`) — this alone would have blocked
    the operator from ever reaching Ready, independent of the metrics toggle bug.
    Re-mapped container ports to the binary's real defaults (`grpc-metrics`: 9666 always,
    `health`: 8081, `metrics`: 8080 conditional) instead of fighting them with flags.
  - Admission Webhooks: `health` and `metrics` container ports were declared backwards
    (`health: 8080`, `metrics: 8081`) relative to the binary's real controller-runtime
    defaults (`--metrics-bind-address` defaults `:8080`, `--health-probe-bind-address`
    defaults `:8081`) — swapped to match. Added `--metrics-bind-address=0` (this
    binary's disable idiom — it has no separate enable/disable flag like the operator)
    when `metrics.enabled=false`.
  - Metrics API Server: probes targeted a `health` port (8080) that doesn't exist on
    this binary at all — confirmed against KEDA's own upstream deployment manifest that
    `/healthz`/`/readyz` are served on the secure API port (6443) over HTTPS, with no
    separate plain-HTTP health port. Updated probes accordingly, and updated
    `templates/tests/test-connection.yaml`'s health check to use HTTPS with
    `--no-check-certificate` (kubelet's own probes never validate certs either,
    regardless of scheme, so this doesn't weaken anything a real probe wouldn't already
    accept).
  - Updated `service-operator.yaml`, `service-admission-webhooks.yaml`, and
    `networkpolicy.yaml` to match the corrected port numbers throughout, and split the
    previously-unconditional operator NetworkPolicy rule on port 9666 (now correctly
    understood as the always-required gRPC channel, left unconditional) from a new,
    separate rule for the real Prometheus port 8080 (conditional on `metrics.enabled`).
  - Follow-up completed: removed the Metrics API Server's vestigial `health` container
    port (8080) — there is no separate health port on this binary, health lives on the
    secure `https` port. Corrected its `metrics` port from the fictional `9022` to the
    adapter's real `--port` default of `8080` (`cmd/adapter/main.go`'s
    `RunMetricsServer`, always running regardless of `metrics.enabled` — the gate only
    controls whether the chart exposes/advertises it via Service and NetworkPolicy).
    Updated `service-metrics-apiserver.yaml` and `networkpolicy.yaml` to match, and
    documented (in both the template and the README's NetworkPolicy section) that
    `networkPolicy.kubeApiServerCIDR` and this component's default health checks are
    mutually exclusive: both kube-aggregator traffic and kubelet's probes hit the same
    `https` port, and NetworkPolicy has no way to allow "the API server from a specific
    CIDR" and "kubelet from the node" on the same port simultaneously.
- **`admissionWebhooks.enabled` now defaults to `false`.** This chart never provisioned
  the webhook server's TLS cert, so a plain `helm install` with the old default
  (`true`) produced a CrashLoopBackOff webhooks Deployment out of the box. Also
  disabled in the `ha-values.yaml` CI profile — `ct` generates a random namespace per
  test run, so there's no way to pre-provision a namespace-scoped Certificate/Secret
  for it there either. Real CI coverage of the webhook+TLS path needs either a
  chart-generated self-signed cert (a natural follow-up: many charts solve exactly
  this with Helm's `genSelfSignedCert`) or a values profile with a real `caBundle`;
  neither exists yet.
- `templates/pdb.yaml`'s `---` document separators were unconditional, so when a PDB
  in the middle or at the end of the file didn't render (its component's replicaCount
  was 1), the separator could produce a stray empty YAML document. Moved each `---` to
  immediately precede an actually-rendered PDB instead. Verified with 0, 1
  (asymmetric), and all 3 PDBs rendering — no stray separators in any case.
- `validatingwebhookconfiguration.yaml` rendered a user-supplied `caBundle` even when
  `certManagerCertificate` was also set — cert-manager's CA injector owns and
  overwrites that field on reconcile regardless, so setting both just meant the
  chart's own value would immediately be clobbered. Now `caBundle` only renders when
  `certManagerCertificate` is unset, matching how the two are documented as
  alternatives.
- Tightened the operator's gRPC metrics-resolution port (9666) ingress rule from
  port-only (any source) to a `podSelector` restricted to Metrics API Server pods —
  a portable, reliable selector was available (the same one the Metrics API Server's
  own egress rule already uses in the reverse direction), so there was no need to
  leave this one open to any source in-namespace.
- **Operator and Metrics API Server crash-looped on every real cluster** trying to
  read a TLS cert for their mutual TLS gRPC channel (port 9666) that nothing ever
  provisioned (`open /certs/ca.crt: no such file or directory` on the operator;
  `open apiserver.local.config/certificates/ca.crt: no such file or directory` on the
  adapter). Verified against `pkg/certificates/certificate_manager.go`
  (`kedacore/keda @ v2.16.0`): the operator has a built-in self-signed CA/cert
  rotation mechanism (`open-policy-agent/cert-controller`, gated behind
  `--enable-cert-rotation`) that generates a cert bundle, stores it in a
  `<fullname>-certs` Secret, and auto-patches the resulting `caBundle` onto both the
  `ValidatingWebhookConfiguration` and the `APIService`. This was never enabled.
  - Enabled `--enable-cert-rotation=true` on the operator (not user-toggleable —
    required for basic functionality, not an optional feature), passing
    `--operator-service-name`/`--metrics-server-service-name`/`--webhooks-service-name`/
    `--validating-webhook-name` explicitly so the generated cert's SANs and the
    resources the rotator patches match this chart's actual (release-scoped)
    resource names, not the binary's hardcoded defaults.
  - Added a writable `emptyDir` at `/certs` to the operator (the rotator writes its
    local copy there in addition to the Secret).
  - Added `--cert-dir`/`--tls-cert-file`/`--tls-private-key-file`/`--client-ca-file`
    to the Metrics API Server (cross-checked against KEDA's own upstream
    `config/metrics-server/deployment.yaml`, which passes this same flag set) and
    mounted the `<fullname>-certs` Secret read-only at `/certs`.
  - Switched Admission Webhooks from the separately-provisioned
    `<fullname>-webhooks-tls` Secret to the same shared `<fullname>-certs` Secret,
    since the rotator manages TLS for all three components from one bundle. Removed
    `admissionWebhooks.caBundle`/`.certManagerCertificate` and
    `metricsApiServer.apiService.caBundle` — the rotator overwrites any manually-set
    `caBundle` on its next reconcile regardless, so they were dead the moment
    cert-rotation was enabled. Replaced the README's "Webhook TLS with cert-manager"
    section with "TLS Certificates", describing the new automatic mechanism.
  - `admissionWebhooks.enabled` stays `false` by default for now (not reverted to
    `true`) pending a green CI run that actually confirms this mechanism works
    end-to-end in `ct`'s kind cluster — this fix is verified against KEDA's source,
    not yet against a live cluster.
- If `serviceAccount.name` was explicitly set, all three `keda.*ServiceAccountName`
  helpers correctly resolved to that one shared name, but `templates/serviceaccount.yaml`
  still rendered three separate `ServiceAccount` manifests with the identical name —
  three objects fighting over ownership of one name, with unpredictable labels.
  Now renders exactly one `ServiceAccount` when a custom name is set.
- `bootstrap.sh` applied the `keda-crds` CRDs but didn't wait for them to reach
  `Established`, risking a race with the immediately-following `ct install` of the
  `keda` chart. Added `kubectl wait --for=condition=Established` for all 6 CRDs.
- Removed `global.storageClass` — this chart has no PVCs/stateful workloads, so the
  value was declared in values/schema/README but referenced by no template.
- Corrected `templates/tests/test-connection.yaml`'s timeout message: 6 attempts ×
  10s `wget --timeout` + 5 × 10s sleeps between them is ~110s worst case, not ~60s.
- The Admission Webhooks `ClusterRole` rendered unconditionally even with
  `admissionWebhooks.enabled=false` (its `ClusterRoleBinding` was already correctly
  gated). Gated the `ClusterRole` too, matching the rest of that component's resources.
- Cleanup misses from the cert-rotation rewrite: `clusterrolebinding.yaml` still had a
  dead `caBundle` conditional branch referencing a value that no longer exists; the
  README's Prerequisites section still recommended cert-manager, contradicting the
  new "TLS Certificates" section; `NOTES.txt`'s production checklist still described
  the old manual cert-manager/external-secrets provisioning model instead of the
  operator's automatic cert rotation. Fixed all three for consistency.
- **Metrics API Server's `helm test` failed intermittently on first install**
  (`wget: TLS error from peer (alert code 40): handshake failure`, then
  `FAIL: KEDA metrics API server timed out after ~110s`). Root cause: the
  `<fullname>-certs` Secret is created by the operator's cert-rotation reconcile,
  which only runs after the operator itself has started — on a fresh install the
  Metrics API Server (and Admission Webhooks, when enabled) pod schedules and starts
  before that Secret exists, so its `--tls-cert-file`/`--tls-private-key-file` paths
  are missing and the container exits immediately. Kubernetes then retries it under
  `CrashLoopBackOff`, whose exponential delay (10s/20s/40s/80s...) can outlast the
  test hook's ~110s retry budget even though the pod stabilizes shortly after.
  Added a `wait-for-certs` initContainer to both the Metrics API Server and Admission
  Webhooks Deployments that polls every 2s for the cert files to appear, so the main
  container never starts (and never crash-loops) until the Secret is actually ready.
- **The Metrics API Server's `helm test` still failed after the fix above**, now
  immediately and consistently: `wget: TLS error from peer (alert code 40): handshake
  failure` on every attempt, even against a Metrics API Server pod that was already
  `Ready` with zero restarts. Root cause: busybox 1.36's built-in `wget` TLS client
  only supports a small, dated cipher-suite set and cannot negotiate with Go's
  `crypto/tls` defaults (the `k8s.io/apiserver` library the metrics-apiserver uses)
  — a documented busybox bug, fixed only in 1.37
  (lists.busybox.net/pipermail/busybox/2022-January/089412.html). Switched
  `templates/tests/test-connection.yaml` from `busybox:1.36.1`/`wget` to
  `curlimages/curl:8.7.1`/`curl` (same image the keycloak chart's `test-smoke.yaml`
  already uses), which links a full TLS stack with no such gap.
- **The APIService's `insecureSkipTLSVerify: true` could break `helm upgrade`.**
  Kubernetes requires an APIService to set exactly one of `caBundle` /
  `insecureSkipTLSVerify` — never both. The operator's cert rotator patches a real
  `caBundle` onto this APIService shortly after first install, but the chart kept
  unconditionally re-rendering `insecureSkipTLSVerify: true` on every `helm upgrade`
  regardless, which would fight (or outright conflict with) whatever the rotator had
  already patched in. Now only rendered when `.Release.IsUpgrade` is false — the
  rotator owns this field from the second reconcile onward.
- `dpdp.dataResidency.enabled: true` with an empty (default) `region` rendered a
  meaningless `dpdp.arieotech.com/data-residency-region: ""` annotation instead of
  failing fast. Added an `if`/`then` to `values.schema.json` requiring a non-empty
  `region` whenever `dataResidency.enabled` is `true`, and guarded
  `keda.podAnnotations` in `_helpers.tpl` to only emit the annotation when both are set.
- `metricsApiServer.apiService.insecureSkipTLSVerify` was schema-validated as any
  boolean, but this chart exposes no `caBundle` alternative — setting it to `false`
  would render an APIService with neither field set (Kubernetes requires exactly
  one), failing at install time and permanently blocking the operator's cert
  rotator from ever getting a chance to patch a real `caBundle` in. Constrained the
  schema to `const: true`.
- Moved the `APIService` out of `clusterrolebinding.yaml` into its own
  `templates/apiservice.yaml` — it's a cluster-scoped aggregation resource, not an
  RBAC binding, and was easy to miss while troubleshooting external-metrics
  registration issues buried at the bottom of an RBAC file.
- README's Prerequisites section didn't mention that the cluster-scoped
  `v1beta1.external.metrics.k8s.io` APIService has a fixed name, so only one
  release of this chart can exist per cluster — a second release anywhere would
  collide on that object. Documented it.
- **The `insecureSkipTLSVerify: true` "bootstrap fallback" from two entries above
  broke every fresh install.** Confirmed via a live `ct install` failure, not
  theory: the operator's cert rotator's first reconcile (a few seconds after
  startup) tries to patch a `caBundle` onto the APIService the chart already
  created with `insecureSkipTLSVerify: true`, and the API server's own validation
  rejects it outright — `spec.insecureSkipTLSVerify: Invalid value: true: may not
  be true if caBundle is present`. The `{{- if not .Release.IsUpgrade }}` guard
  added earlier was based on the wrong theory (that this only mattered on
  `helm upgrade`); the actual failure is on first install. Kubernetes does not
  require either field to be set — only that they're not set together — so the
  fix is to never render `insecureSkipTLSVerify` at all and let the rotator own
  the field from its very first reconcile. Removed
  `metricsApiServer.apiService.insecureSkipTLSVerify` from `values.yaml` and
  `values.schema.json` entirely, since setting it to `true` is now a confirmed
  install-breaking footgun, not a legitimate configuration choice.
- The `dpdp.dataResidency` `if`/`then` schema's `if` clause checked
  `enabled: { const: true }` under `properties` without `required: ["enabled"]` —
  in JSON Schema, `properties` alone doesn't assert presence, so an object
  missing `enabled` entirely (not just `enabled: false`) would vacuously satisfy
  the `if` and incorrectly require `region`. Added `required: ["enabled"]` to the
  `if` clause. Verified with `--set-json 'dpdp={"dataResidency":{"region":""}}'`
  (an `enabled`-less object) passing before and after, and the `enabled: true`
  cases still enforcing `region` correctly.
- `KedaScaledObjectError` and `KedaTriggerAuthenticationError` alerted on a raw
  counter (`keda_scaledobject_errors_total > 0` / `keda_trigger_totals{type="error"}
  > 0`) — both are monotonically increasing, so once a single error was ever
  recorded, the alert would fire permanently, never resolving even if the errors
  stopped. Switched both to `increase(...[5m]) > 0`, matching the `rate(...)`
  pattern the Metrics API Server's workqueue alert already used.
- `serviceAccount.create: false` with no `name` set silently fell back to the
  namespace's `default` ServiceAccount, and every KEDA ClusterRoleBinding/
  RoleBinding would then grant its permissions to that default SA — an easy to
  miss security footgun. Added an `if`/`then` requiring a non-empty `name`
  whenever `create` is `false`.
- `secrets` keys are used verbatim as the Secret name's suffix
  (`<fullname>-<key>`), but the schema didn't validate them — an uppercase or
  underscore-containing key would pass `helm lint` and only fail at
  `helm install` with an unhelpful Kubernetes API error. Added `propertyNames`
  validation requiring a valid Kubernetes name segment.
- `arieotech-lib`'s `serviceAccountTokenVolume`/`...VolumeMount` helpers (used by
  all three KEDA components) hardcoded the generic volume name `kube-api-access`.
  Since charts built on this library also accept user-supplied
  `extraVolumes`/`extraVolumeMounts`, this was a silent collision risk with a
  user-supplied volume of the same name (duplicate volume names make a pod spec
  invalid) — not with Kubernetes' own auto-injected token volume, which uses a
  randomized suffix and wouldn't apply here anyway since
  `automountServiceAccountToken` is `false`. Renamed to
  `arieotech-kube-api-access` in `arieotech-lib`.
- `KedaMetricsApiServerHighErrorRate` measured `workqueue_adds_total` (workqueue
  processing throughput), not errors — a naming/intent mismatch that could
  confuse on-call routing or dashboards keyed on alert name. Renamed to
  `KedaMetricsApiServerHighWorkqueueRate`, matching what the alert's own
  `summary`/`description` annotations already said.
- `secrets.*.data`/`.stringData`/`.annotations` were typed as generic objects in
  `values.schema.json`, so a non-string value (e.g. a bare number) would pass
  `helm lint` and only fail later at `kubectl apply`. Added
  `additionalProperties: {"type": "string"}` to all three.
- README's TLS Certificates section said dependent pods "may crash-loop briefly"
  waiting for the `<fullname>-certs` Secret — stale as of the `wait-for-certs`
  initContainer fix earlier in this changelog, which makes them wait instead of
  crash-looping. Corrected.
- Corrected a comment in `arieotech-lib`'s `serviceAccountTokenVolume` helper
  that inaccurately described Kubernetes' own auto-injected token volume as
  using the same bare name this helper renames away from — it actually uses a
  randomized suffix, so the real collision risk was always with user-supplied
  volumes, not Kubernetes' own injection.
- `metricsApiServer.logLevel` was schema-validated as any string, but it's
  passed to the adapter as klog's `--v=<value>` (unlike the operator's
  zap-based `debug`/`info`/`error` levels a few fields above it in the same
  file) — a level name like `"info"` would pass `helm lint` and crash the
  adapter at runtime. Added a `^[0-9]+$` pattern.
