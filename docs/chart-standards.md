# Arieotech Production Baseline

Every chart in this repository must meet all criteria in this checklist before merge to main.
This document is public — it is the signal that differentiates Arieotech charts from every other chart library.

## Security

- [ ] **PSA restricted-mode compatible** — installs without `privileged`, `allowPrivilegeEscalation`, or `hostPath`
- [ ] **Non-root containers** — all containers run with `runAsNonRoot: true` and an explicit `runAsUser` ≥ 1000
- [ ] **Read-only root filesystem** — `readOnlyRootFilesystem: true`; writable paths use `emptyDir` or explicit PVCs
- [ ] **Drop ALL capabilities** — `capabilities.drop: [ALL]`; add back only specific caps with documented justification
- [ ] **seccompProfile: RuntimeDefault** — on both pod and container security contexts
- [ ] **No `latest` image tags** — pinned to semver or digest; `appVersion` in `Chart.yaml` matches default tag
- [ ] **No hardcoded secrets** — all secrets via `existingSecret` pattern or `helm --set` at install time

## Networking

- [ ] **NetworkPolicy enabled by default** — `networkPolicy.enabled: true` in default `values.yaml`
- [ ] **Deny-all base** — both Ingress and Egress policyTypes declared; no implicit allow
- [ ] **Explicit DNS egress** — UDP and TCP port 53 always allowed in egress
- [ ] **Port documentation** — every port in the NetworkPolicy has a comment explaining its purpose

## Reliability

- [ ] **PodDisruptionBudget** — present and enabled by default when `replicaCount > 1`
- [ ] **Resource requests and limits** — both set; `memory` limit always set; `cpu` limit optional with justification
- [ ] **Liveness, readiness, and startup probes** — all three configured; startup probe covers slow-start workloads
- [ ] **Pod anti-affinity** — default affinity spreads replicas across nodes via `preferredDuringScheduling`
- [ ] **TopologySpreadConstraints** — present for stateful and multi-replica workloads

## Observability

- [ ] **ServiceMonitor** — present (Prometheus Operator); disabled by default, enabled with `metrics.serviceMonitor.enabled: true`
- [ ] **Named ports** — all Service ports have names matching the ServiceMonitor port reference
- [ ] **PrometheusRule** — present for charts with known SLI/alert rules

## Configuration

- [ ] **JSON Schema** — `values.schema.json` covers all top-level keys; `helm install` fails fast on invalid values
- [ ] **Production defaults** — `values.yaml` defaults are production-ready, not demo-ready
- [ ] **`ci/default-values.yaml`** — minimal working install for `ct install` (may relax security for CI speed)
- [ ] **`ci/ha-values.yaml`** — HA mode test; must pass `ct install`
- [ ] **`ci/soc2-values.yaml`** — SOC2-hardened profile test

## Compliance

- [ ] **SOC2 defaults** — `soc2.auditLogging.enabled` structured logging; TLS option present
- [ ] **DPDP defaults** — `dpdp.piiMasking.enabled`; data residency annotation support
- [ ] **No PII in default labels/annotations** — chart defaults never emit email, name, or user ID values

## Documentation

- [ ] **`README.md`** — Quick start, prerequisites, production checklist, HA config, compliance sections
- [ ] **`CHANGELOG.md`** — Entries from version 0.1.0; breaking changes section when applicable
- [ ] **`NOTES.txt`** — Post-install instructions including production checklist reminder
- [ ] **Migration guide** — Present in `docs/migration-guides/` for charts replacing deprecated charts
- [ ] **`Chart.yaml` annotations** — `artifacthub.io/changes`, `artifacthub.io/images`, relevant links

## CI

- [ ] **`ct lint` passes** — no schema errors, valid YAML
- [ ] **`ct install` passes** — all `ci/*.yaml` profiles install cleanly on kind
- [ ] **Trivy config scan** — no HIGH or CRITICAL misconfigurations in rendered templates
- [ ] **`helm test` passes** — connection test pod confirms the workload is reachable

## Chart.yaml requirements

```yaml
apiVersion: v2
name: keda
description: Production-grade KEDA — fixes namespace-scoped RBAC and missing CRD separation
type: application
version: 0.1.0              # chart version — bumped on every merge
appVersion: "2.15.1"        # upstream app version matching default image tag
maintainers:
  - name: Arieotech
    email: helm@arieotech.com
annotations:
  artifacthub.io/license: Apache-2.0
  artifacthub.io/changes: |
    - kind: added
      description: "Initial release — namespace-scoped RBAC, PSA restricted-mode, NetworkPolicy"
```
