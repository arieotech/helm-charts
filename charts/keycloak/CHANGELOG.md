# Changelog

All notable changes to this chart are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Chart versions follow [Semantic Versioning](https://semver.org/).

## [0.3.3] - 2026-06-11

### Changed
- **README overhaul** — added Table of Contents, "How HA clustering works" architecture section,
  full "Installing the Chart" section with production and dry-run patterns, "Testing" section
  documenting `helm test` and smoke test coverage, "Upgrading" section with 0.3.3 migration notes,
  "Istio Ambient Mesh" section, and parameter tables for `dbchecker`, `soc2`, and `dpdp`. All
  configuration keys now have corresponding table entries; no undocumented values remain.

### Fixed

- **`readOnlyRootFilesystem` crash on startup** — Keycloak's Quarkus runtime writes
  `transformed-bytecode.jar` to `/opt/keycloak/lib/quarkus/` on every cold start when
  the env-var configuration differs from the pre-built image defaults. With
  `readOnlyRootFilesystem: true` (our PSA baseline) this caused an immediate crash loop.
  Fixed by adding an `init-quarkus` init container that copies the pre-built Quarkus lib
  into a writable `quarkus-lib` emptyDir, which the main container mounts at the same
  path. Uses `cp -r` (not `cp -rp` — `-p` fails as non-root on a root-owned emptyDir).

- **`KC_HEALTH_ENABLED` missing — all probes failed on every install** — Keycloak 26.x
  does not expose `/health/*` on port 9000 unless `KC_HEALTH_ENABLED=true` is explicitly
  set. Without it the startup, liveness, and readiness probes all returned "connection
  refused", causing the StatefulSet to never reach Ready state. `KC_HEALTH_ENABLED=true`
  is now set unconditionally. `KC_METRICS_ENABLED=true` is also added when
  `metrics.enabled=true` so the `/metrics` endpoint is actually active.

- **Management port 9000 missing from main Service** — the main ClusterIP Service only
  exposed HTTP (80) and HTTPS (443). Port 9000 (Keycloak management interface) was absent,
  so Prometheus ServiceMonitors configured with `port: management` could not scrape
  `/metrics`, and `helm test` pods could not reach `/health/*`. Port 9000 is now a named
  `management` port on the main Service.

- **Headless Service JGroups port was 7600 (wrong)** — Keycloak 25+ changed the
  Infinispan JGroups bind port from 7600/57600 to 7800/57800. The NetworkPolicy was
  updated in v0.2.0 but the headless Service still exposed 7600. Fixed to 7800 + 57800.

### Added

- **Full OIDC E2E smoke test** (`templates/tests/test-smoke.yaml`) — runs as part of
  `helm test` (and therefore `ct install` in CI). Covers:
  - Health checks on management port 9000 (`/health/ready`, `/health/live`)
  - Admin token acquisition (master realm)
  - Realm create → verify in list
  - Public OIDC client creation
  - User creation with full profile (`firstName`, `lastName`, `email`,
    `emailVerified: true` — required by KC 26.x `VERIFY_PROFILE` authenticator for
    direct grant to succeed)
  - Password set via reset-password endpoint
  - OIDC direct grant with `scope=openid` → access_token + id_token + refresh_token
  - Userinfo endpoint (HTTP 200)
  - Token refresh
  - Logout (session revocation)
  - Realm cleanup

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
