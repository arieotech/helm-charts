# Changelog

All notable changes to this chart are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Chart versions follow [Semantic Versioning](https://semver.org/).

## [0.3.2] - 2026-06-05

### Changed
- Expanded README with troubleshooting guide, performance tuning section, External Secrets Operator guide, production checklist, and full configuration reference

## [0.3.1] - 2026-06-04

### Added
- Artifact Hub category (`security`), expanded links, and `containsSecurityUpdates` annotation

## [0.3.0] - 2026-06-04

### Changed
- Track Keycloak 26.6.2 (upstream app version bump from 26.1.4)

## [0.2.1] - 2026-05-29

### Fixed
- Icon URL updated to working keycloak.org path (`icon.svg` replaces broken `keycloak_icon_64px.svg`)

## [0.2.0] - 2026-05-27

### Fixed

- **JGroups ports corrected to 7800/57800** — Keycloak 25+ changed the Infinispan
  clustering ports from 7600/57600 to 7800/57800. The NetworkPolicy and egress rules
  were updated accordingly. Clusters on Keycloak 25+ would have had silent clustering
  failures with the old port values.

- **Feature flags now wired** — `keycloak.features.tokenExchange` and
  `keycloak.features.adminFineGrainedAuthz` values existed in values.yaml but were
  never passed to the container as `KC_FEATURES`. They now correctly map to the
  `KC_FEATURES` environment variable.

- **Proxy configuration no longer hardcoded** — `KC_PROXY_HEADERS` was hardcoded to
  `xforwarded` and `KC_HOSTNAME_STRICT` was hardcoded to `false`. Both are now
  configurable via the new `proxy.*` values section.

### Added

- **Realm import** (`realmImport.enabled`) — provide realm JSON in values and the chart
  mounts it at `/opt/keycloak/data/import/` with `--import-realm` in the startup args.
  Import is idempotent — Keycloak skips realms that already exist. Pod restarts when
  realm ConfigMap changes (checksum annotation).

- **Database checker init container** (`dbchecker.enabled`) — a lightweight busybox
  init container that polls PostgreSQL on `database.host:database.port` before
  Keycloak starts. Prevents false startup failures during cluster cold-starts when
  the database pod may not be ready yet.

- **`skipInitContainers`** — set `true` to skip init containers entirely when the
  deployment environment requires it. Keycloak's own retry loop handles database
  connectivity in this case.

- **Generic secrets** (`secrets.*`) — create arbitrary `Secret` resources alongside
  the chart. Useful for LDAP bind credentials, SMTP passwords, and custom provider
  configuration without needing a separate manifest.

- **`terminationGracePeriodSeconds`** (default: 60) — configurable termination grace
  period. 60s gives Infinispan time to redistribute session ownership to surviving
  replicas before the pod exits. Increase for clusters with large session caches.

- **AZ topology spread constraint** — a second `TopologySpreadConstraint` on
  `topology.kubernetes.io/zone` with `whenUnsatisfiable: ScheduleAnyway` added to
  defaults alongside the existing node-level constraint. Pods now spread across both
  nodes and availability zones by default.

### Changed

- **Startup probe window extended to 315s** — changed from `initialDelaySeconds: 30,
  failureThreshold: 18, periodSeconds: 10` (210s max) to `initialDelaySeconds: 15,
  failureThreshold: 60, periodSeconds: 5` (315s max). Large realms with
  `--import-realm` can take 3–4 minutes on a cold start, especially on the first
  install with many clients and roles.



All notable changes to this chart are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Chart versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-05-19

### Added
- Initial release — production-grade Keycloak chart using official `quay.io/keycloak/keycloak` image
- HA mode with Infinispan session clustering via Kubernetes DNS discovery (JGroups `kubernetes` stack)
- StatefulSet with `Parallel` pod management for faster rolling updates
- JSON Schema validation for all values (`values.schema.json`)
- NetworkPolicy enabled by default — deny-all with explicit allow-list for HTTP, HTTPS, management, JGroups
- PSA restricted-mode compatible security contexts
- PodDisruptionBudget (enabled by default when replicaCount > 1)
- HorizontalPodAutoscaler support (autoscaling/v2)
- Prometheus Operator ServiceMonitor support
- SOC2 defaults: structured JSON audit logging, TLS enforcement option
- DPDP defaults: PII masking flag, data residency namespace annotation support
- Default pod anti-affinity to spread replicas across nodes
- TopologySpreadConstraints for even distribution
- Startup probe with 180s tolerance for large-realm cold starts
- `helm test` connection test pod
- CI test profiles: default, HA, SOC2-hardened
### Keycloak version
- Default appVersion: 25.0.6
