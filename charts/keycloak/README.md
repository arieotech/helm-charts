# Keycloak

Production-grade Helm chart for [Keycloak](https://www.keycloak.org/) — the open-source IAM and SSO platform.

**HA clustering · PSA restricted-mode · SOC2/DPDP defaults · JSON Schema validation · NetworkPolicy**

## Table of Contents

- [Why this chart exists](#why-this-chart-exists)
- [Prerequisites](#prerequisites)
- [Installing the Chart](#installing-the-chart)
- [Accessing Keycloak](#accessing-keycloak)
- [Uninstalling the Chart](#uninstalling-the-chart)
- [How HA clustering works](#how-ha-clustering-works)
- [Configuration](#configuration)
  - [Image](#image)
  - [Replicas and HA](#replicas-and-ha)
  - [Admin credentials](#admin-credentials)
  - [Database](#database)
  - [Database checker](#database-checker)
  - [Proxy and hostname](#proxy-and-hostname)
  - [Ingress and TLS](#ingress-and-tls)
  - [Cache / clustering](#cache--clustering)
  - [Service](#service)
  - [Persistence](#persistence)
  - [Custom themes and providers](#custom-themes-and-providers)
  - [Resources](#resources)
  - [JVM options](#jvm-options)
  - [Probes](#probes)
  - [ServiceAccount](#serviceaccount)
  - [Pod scheduling](#pod-scheduling)
  - [Pod annotations and labels](#pod-annotations-and-labels)
  - [Realm import](#realm-import)
  - [Extra env, volumes, and sidecars](#extra-env-volumes-and-sidecars)
  - [Generic secrets](#generic-secrets)
  - [Keycloak features](#keycloak-features)
- [NetworkPolicy](#networkpolicy)
- [Metrics and monitoring](#metrics-and-monitoring)
- [SOC2 compliance](#soc2-compliance)
- [DPDP compliance (India)](#dpdp-compliance-india)
- [Using External Secrets Operator](#using-external-secrets-operator)
- [Istio Ambient Mesh](#istio-ambient-mesh)
- [Performance tuning](#performance-tuning)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Upgrading](#upgrading)
- [Production checklist](#production-checklist)
- [Support](#support)

---

## Why this chart exists

The official Keycloak project chart has significant production gaps that block real-world deployments:

| Gap | Impact |
|-----|--------|
| No PSA restricted-mode support | `readOnlyRootFilesystem: true` crashes Keycloak at startup — Quarkus writes to `/opt/keycloak/lib/quarkus/` on every cold start |
| `KC_HEALTH_ENABLED` not set | All probes fail with "connection refused" on every fresh install |
| No NetworkPolicy | Pod networking is open by default; ingress controller and inter-pod clustering are unrestricted |
| No JSON Schema validation | Invalid values are silently ignored instead of rejected at install time |
| Management port not on main Service | Prometheus ServiceMonitors can't scrape `/metrics`; `helm test` pods can't reach `/health/*` |
| JGroups ports not updated | Clustering fails silently on Keycloak 25+ (ports changed from 7600 to 7800) |
| No SOC2/DPDP compliance defaults | Each team re-implements audit logging and PII masking from scratch |
| No E2E validation | Charts ship without any OIDC token-flow test |

This chart fixes all of the above and ships production defaults out of the box.

---

## Prerequisites

- Kubernetes 1.27+
- Helm 3.12+
- PostgreSQL 15+ (external) — `bundled.enabled` is available for development only
- cert-manager (for TLS — recommended for production)
- Prometheus Operator (for ServiceMonitor — optional)

---

## Installing the Chart

Add the Arieotech Helm repository:

```bash
helm repo add arieotech https://charts.arieotech.com
helm repo update
```

**Minimal install (development):**

```bash
helm install keycloak arieotech/keycloak \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword=changeme \
  --set database.host=postgres.keycloak.svc.cluster.local \
  --set database.password=changeme \
  --set replicaCount=1 \
  --set pdb.enabled=false \
  --set networkPolicy.enabled=false
```

**Production install (recommended pattern):**

```bash
# Create secrets first
kubectl create namespace keycloak
kubectl create secret generic keycloak-admin \
  --from-literal=admin-password=<strong-password> \
  -n keycloak
kubectl create secret generic keycloak-db \
  --from-literal=db-password=<strong-password> \
  -n keycloak

# Install
helm install keycloak arieotech/keycloak \
  --namespace keycloak \
  --set keycloak.auth.existingSecret=keycloak-admin \
  --set database.host=<postgres-host> \
  --set database.existingSecret=keycloak-db \
  --set dbchecker.enabled=true \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set "ingress.hosts[0].host=keycloak.example.com" \
  --set "ingress.hosts[0].paths[0].path=/" \
  --set "ingress.hosts[0].paths[0].pathType=Prefix" \
  --set "ingress.tls[0].secretName=keycloak-tls" \
  --set "ingress.tls[0].hosts[0]=keycloak.example.com"
```

**Dry-run to preview manifests:**

```bash
helm install keycloak arieotech/keycloak \
  --namespace keycloak \
  --dry-run \
  --set keycloak.auth.adminPassword=changeme \
  --set database.host=postgres.example.com
```

**Install from a values file:**

```bash
helm install keycloak arieotech/keycloak \
  --namespace keycloak \
  -f my-values.yaml
```

---

## Accessing Keycloak

**Via Ingress (production):**

Set `ingress.enabled=true` and configure a hostname — see [Ingress and TLS](#ingress-and-tls) below.

**Via port-forward (local testing):**

```bash
kubectl port-forward -n keycloak svc/keycloak 8080:80
```

Admin console: `http://localhost:8080/admin`

Default admin user: `admin` (set via `keycloak.auth.adminUser`)

---

## Uninstalling the Chart

```bash
helm uninstall keycloak --namespace keycloak
```

PersistentVolumeClaims are not deleted automatically. Remove them manually if no longer needed:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=keycloak -n keycloak
```

---

## How HA clustering works

This chart deploys Keycloak as a Kubernetes `StatefulSet` (not a `Deployment`) because stable pod DNS names are required for Infinispan session-cache discovery.

**Clustering sequence:**

1. The headless Service (`<release>-keycloak-headless`) provides stable DNS entries: `keycloak-0.<release>-keycloak-headless.<namespace>.svc.cluster.local`.
2. Keycloak uses the `kubernetes` JGroups stack (`cache.stack: kubernetes`) to perform DNS discovery across all headless service endpoints.
3. Infinispan replicates session data to `cache.owners` pod replicas (default: 2). A single-pod failure loses no sessions.
4. JGroups uses ports 7800 (gossip/unicast) and 57800 (failure detection) — both allowed in the default NetworkPolicy.

**Scaling:**

```bash
kubectl scale statefulset keycloak --replicas=5 -n keycloak
```

Update `replicaCount` in your values file for persistent changes. The default `topologySpreadConstraints` automatically distributes replicas across nodes and availability zones.

---

## Configuration

### Image

| Key | Default | Description |
|-----|---------|-------------|
| `image.registry` | `quay.io` | Image registry |
| `image.repository` | `keycloak/keycloak` | Image repository |
| `image.tag` | `26.6.2` | Image tag |
| `image.digest` | `""` | Digest takes precedence over tag — recommended for production |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `global.imagePullSecrets` | `[]` | Image pull secrets applied to all pods |

**Pin to digest in production:**

```yaml
image:
  tag: "26.6.2"
  digest: "sha256:<digest>"
```

---

### Replicas and HA

| Key | Default | Description |
|-----|---------|-------------|
| `replicaCount` | `3` | Pod replicas — minimum 3 for HA |
| `autoscaling.enabled` | `false` | Enable HPA |
| `autoscaling.minReplicas` | `3` | HPA minimum replicas |
| `autoscaling.maxReplicas` | `10` | HPA maximum replicas |
| `autoscaling.targetCPUUtilizationPercentage` | `70` | HPA CPU target |
| `pdb.enabled` | `true` | Enable PodDisruptionBudget |
| `pdb.minAvailable` | `1` | Minimum available pods during disruptions |
| `terminationGracePeriodSeconds` | `60` | Grace period — allows Infinispan to rebalance before exit |

---

### Admin credentials

| Key | Default | Description |
|-----|---------|-------------|
| `keycloak.auth.adminUser` | `admin` | Admin username |
| `keycloak.auth.adminPassword` | `""` | Admin password — dev only, use `existingSecret` in production |
| `keycloak.auth.existingSecret` | `""` | Name of existing Secret containing admin password |
| `keycloak.auth.existingSecretKey` | `admin-password` | Key inside the existing Secret |

**Create the secret manually:**

```bash
kubectl create secret generic keycloak-admin \
  --from-literal=admin-password=<password> \
  -n keycloak
```

```yaml
keycloak:
  auth:
    existingSecret: keycloak-admin
    existingSecretKey: admin-password
```

---

### Database

Keycloak requires PostgreSQL. The `bundled.enabled` option is for development only.

| Key | Default | Description |
|-----|---------|-------------|
| `database.vendor` | `postgres` | DB vendor: `postgres`, `mysql`, `mariadb` |
| `database.host` | `""` | PostgreSQL hostname (required when not using bundled) |
| `database.port` | `5432` | PostgreSQL port |
| `database.name` | `keycloak` | Database name |
| `database.username` | `keycloak` | Database username |
| `database.password` | `""` | Database password — dev only, use `existingSecret` in production |
| `database.existingSecret` | `""` | Name of existing Secret containing DB password |
| `database.existingSecretKey` | `db-password` | Key inside the existing Secret |

**Production pattern:**

```bash
kubectl create secret generic keycloak-db \
  --from-literal=db-password=<password> \
  -n keycloak
```

```yaml
database:
  host: postgres.example.com
  username: keycloak
  existingSecret: keycloak-db
  existingSecretKey: db-password
```

---

### Database checker

The `dbchecker` init container polls PostgreSQL before Keycloak starts, preventing false startup failures during cold cluster restarts where the database pod may not yet be ready.

| Key | Default | Description |
|-----|---------|-------------|
| `dbchecker.enabled` | `false` | Enable the DB checker init container |
| `dbchecker.image.repository` | `busybox` | Init container image |
| `dbchecker.image.tag` | `1.37` | Init container image tag |
| `skipInitContainers` | `false` | Skip all init containers — relies on Keycloak's own retry loop. **Requires `securityContext.readOnlyRootFilesystem: false`** — the `init-quarkus` container that populates `/opt/keycloak/lib/quarkus` is also skipped, so Keycloak will fail to start if the filesystem is read-only. |

**Recommended for production:**

```yaml
dbchecker:
  enabled: true
```

---

### Proxy and hostname

| Key | Default | Description |
|-----|---------|-------------|
| `proxy.mode` | `xforwarded` | `KC_PROXY_HEADERS`: `xforwarded` (nginx/ALB) or `forwarded` (RFC 7239) |
| `proxy.hostnameStrict` | `"false"` | `KC_HOSTNAME_STRICT`: reject requests for unknown hostnames |
| `proxy.http.enabled` | `true` | Enable HTTP listener — set `false` for end-to-end TLS |

---

### Ingress and TLS

| Key | Default | Description |
|-----|---------|-------------|
| `ingress.enabled` | `false` | Enable Ingress |
| `ingress.className` | `""` | IngressClass name (e.g. `nginx`) |
| `ingress.annotations` | `{}` | Ingress annotations |
| `ingress.hosts` | see values | Ingress host rules |
| `ingress.tls` | `[]` | TLS configuration |

**With cert-manager:**

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-buffer-size: "128k"
  hosts:
    - host: keycloak.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: keycloak-tls
      hosts:
        - keycloak.example.com
```

**With an existing TLS secret:**

```yaml
ingress:
  enabled: true
  tls:
    - secretName: my-existing-tls-secret
      hosts:
        - keycloak.example.com
```

---

### Cache / clustering

Keycloak uses Infinispan for distributed session storage. JGroups DNS discovery requires stable pod names — the chart uses a StatefulSet for this reason.

| Key | Default | Description |
|-----|---------|-------------|
| `cache.stack` | `kubernetes` | Discovery stack: `kubernetes` (DNS), `tcp`, `udp` |
| `cache.owners` | `2` | Number of replicas holding a copy of each session entry |

```yaml
replicaCount: 3
cache:
  stack: kubernetes
  owners: 2
```

---

### Service

| Key | Default | Description |
|-----|---------|-------------|
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | HTTP service port |
| `service.httpsPort` | `443` | HTTPS service port |
| `service.annotations` | `{}` | Annotations (e.g. AWS NLB) |

The Service exposes three named ports: `http` (80), `https` (443), and `management` (9000). The `management` port is required for Prometheus ServiceMonitor scraping and `helm test`.

---

### Persistence

Used for custom themes and provider JARs. Disabled by default — use `extraVolumes` for read-only providers.

| Key | Default | Description |
|-----|---------|-------------|
| `persistence.enabled` | `false` | Enable PVC for themes/providers |
| `persistence.size` | `1Gi` | PVC size |
| `persistence.storageClass` | `""` | Storage class (cluster default if empty) |
| `global.storageClass` | `""` | Global storage class override |

---

### Custom themes and providers

Mount a theme or provider JAR via an init container:

```yaml
initContainers:
  - name: copy-theme
    image: my-registry/my-theme:1.0.0
    command: ["cp", "-r", "/theme", "/themes"]
    volumeMounts:
      - name: themes
        mountPath: /themes

extraVolumes:
  - name: themes
    emptyDir: {}

extraVolumeMounts:
  - name: themes
    mountPath: /opt/keycloak/themes/my-theme
```

---

### Resources

| Key | Default | Description |
|-----|---------|-------------|
| `resources.requests.cpu` | `500m` | CPU request |
| `resources.requests.memory` | `1Gi` | Memory request |
| `resources.limits.memory` | `2Gi` | Memory limit — no CPU limit (prevents token validation throttling) |

---

### JVM options

```yaml
keycloak:
  javaOpts: "-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

---

### Probes

All probes target the Keycloak management port `9000` — separate from the HTTP service port 8080. Keycloak 26.x requires `KC_HEALTH_ENABLED=true` (set unconditionally by this chart) to activate these endpoints.

| Key | Default | Description |
|-----|---------|-------------|
| `startupProbe.initialDelaySeconds` | `15` | Startup probe initial delay |
| `startupProbe.periodSeconds` | `5` | Startup probe poll interval |
| `startupProbe.failureThreshold` | `60` | Max failures — `60 × 5s = 315s` window for large realm imports |
| `livenessProbe.initialDelaySeconds` | `60` | Liveness probe initial delay |
| `livenessProbe.periodSeconds` | `10` | Liveness probe poll interval |
| `livenessProbe.failureThreshold` | `6` | Liveness failure threshold |
| `readinessProbe.initialDelaySeconds` | `30` | Readiness probe initial delay |
| `readinessProbe.periodSeconds` | `10` | Readiness probe poll interval |
| `readinessProbe.failureThreshold` | `3` | Readiness failure threshold |

---

### ServiceAccount

| Key | Default | Description |
|-----|---------|-------------|
| `serviceAccount.create` | `true` | Create a dedicated ServiceAccount |
| `serviceAccount.name` | `""` | Override name (auto-generated if empty) |
| `serviceAccount.annotations` | `{}` | Annotations (e.g. IAM role for IRSA) |
| `serviceAccount.automountServiceAccountToken` | `false` | Do not auto-mount the service account token |

---

### Pod scheduling

| Key | Default | Description |
|-----|---------|-------------|
| `nodeSelector` | `{}` | Node selector |
| `tolerations` | `[]` | Pod tolerations |
| `affinity` | `{}` | Pod affinity/anti-affinity rules |
| `priorityClassName` | `""` | Priority class name |
| `topologySpreadConstraints` | node + zone spread | Spread replicas across nodes and AZs |

Default topology spread constraints:

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
```

Override to `null` for single-replica development installs:

```yaml
topologySpreadConstraints: null
```

---

### Pod annotations and labels

```yaml
podAnnotations:
  prometheus.io/scrape: "true"
podLabels:
  team: platform
```

---

### Realm import

Provide realm JSON in values — mounted as a ConfigMap and auto-imported on first startup. Keycloak skips import if the realm already exists (idempotent). Pods restart automatically when the realm ConfigMap changes (checksum annotation).

```yaml
realmImport:
  enabled: true
  realms:
    my-realm: |
      {
        "realm": "my-realm",
        "enabled": true,
        "roles": {},
        "clients": []
      }
```

---

### Extra env, volumes, and sidecars

```yaml
keycloak:
  extraEnv:
    - name: KC_LOG_LEVEL
      value: "INFO"

extraVolumes:
  - name: custom-config
    configMap:
      name: my-keycloak-config

extraVolumeMounts:
  - name: custom-config
    mountPath: /opt/keycloak/conf/custom.conf
    subPath: custom.conf

initContainers:
  - name: wait-for-something
    image: busybox:1.37
    command: ["sh", "-c", "until nslookup myservice; do sleep 2; done"]

sidecars:
  - name: log-shipper
    image: fluentbit:3.3
```

---

### Generic secrets

Create arbitrary Secrets alongside the chart — useful for LDAP bind credentials, SMTP passwords, and custom provider config:

```yaml
secrets:
  ldap-bind:
    stringData:
      bindDN: "cn=admin,dc=example,dc=com"
      bindPassword: "changeme"
  smtp-creds:
    stringData:
      username: keycloak@example.com
      password: changeme
```

---

### Keycloak features

```yaml
keycloak:
  features:
    tokenExchange: true          # Required for external IdP federation
    adminFineGrainedAuthz: true  # Fine-grained admin permissions
```

---

## NetworkPolicy

NetworkPolicy is **enabled by default** with a deny-all base and an explicit allow-list:

- HTTP/HTTPS ingress (ports 8080/8443)
- Management port 9000 (health checks and metrics)
- JGroups ports 7800/57800 (inter-pod clustering — Keycloak 25+)
- PostgreSQL egress on `database.port`
- DNS egress (UDP/TCP 53 — always allowed)

| Key | Default | Description |
|-----|---------|-------------|
| `networkPolicy.enabled` | `true` | Enable NetworkPolicy |
| `networkPolicy.ingressNamespaceSelector` | `{}` | Allow ingress from namespace by label |
| `networkPolicy.extraIngress` | `[]` | Additional ingress rules |
| `networkPolicy.extraEgress` | `[]` | Additional egress rules |

**Allow ingress from ingress-nginx:**

```yaml
networkPolicy:
  extraIngress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
      ports:
        - port: 8080
```

**Allow egress to an LDAP server:**

```yaml
networkPolicy:
  extraEgress:
    - to:
        - ipBlock:
            cidr: 10.0.0.5/32
      ports:
        - port: 389
          protocol: TCP
```

---

## Metrics and monitoring

| Key | Default | Description |
|-----|---------|-------------|
| `metrics.enabled` | `true` | Enable `/metrics` endpoint on management port 9000 |
| `metrics.serviceMonitor.enabled` | `false` | Create Prometheus Operator ServiceMonitor |
| `metrics.serviceMonitor.namespace` | `""` | Namespace for ServiceMonitor (default: release namespace) |
| `metrics.serviceMonitor.interval` | `30s` | Scrape interval |
| `metrics.serviceMonitor.scrapeTimeout` | `10s` | Scrape timeout |
| `metrics.prometheusRule.enabled` | `false` | Create PrometheusRule |

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    labels:
      prometheus: kube-prometheus
```

---

## SOC2 compliance

| Key | Default | Description |
|-----|---------|-------------|
| `soc2.auditLogging.enabled` | `true` | Structured JSON audit events to stdout |
| `soc2.enforceTLS` | `true` | Reject plaintext connections |

```yaml
soc2:
  auditLogging:
    enabled: true
  enforceTLS: true
```

---

## DPDP compliance (India)

| Key | Default | Description |
|-----|---------|-------------|
| `dpdp.piiMasking.enabled` | `false` | Mask email/name fields in Keycloak logs |
| `dpdp.dataResidency.enabled` | `false` | Add namespace annotation for OPA/Kyverno policy |
| `dpdp.dataResidency.region` | `""` | AWS/cloud region (e.g. `ap-south-1`) |

```yaml
dpdp:
  piiMasking:
    enabled: true
  dataResidency:
    enabled: true
    region: "ap-south-1"
```

---

## Using External Secrets Operator

Reference ESO-managed secrets by name:

```yaml
keycloak:
  auth:
    existingSecret: keycloak-admin
    existingSecretKey: admin-password

database:
  existingSecret: keycloak-db
  existingSecretKey: db-password
```

Create the secrets via ESO `ExternalSecret` resources pointing to your vault backend (AWS Secrets Manager, HashiCorp Vault, GCP Secret Manager, etc.).

---

## Istio Ambient Mesh

The chart is compatible with [Istio Ambient Mesh](https://istio.io/latest/docs/ops/ambient/). To enroll the namespace:

```bash
kubectl label namespace keycloak istio.io/dataplane-mode=ambient
```

Or enroll only the Keycloak pods via pod labels:

```yaml
podLabels:
  istio.io/dataplane-mode: ambient
```

**Management port exclusion:** Istio Ambient's ztunnel intercepts all TCP traffic by default. To allow Kubernetes health probes to reach port 9000 directly (required for startup/liveness/readiness probes), exclude it:

```yaml
podAnnotations:
  traffic.sidecar.istio.io/excludeInboundPorts: "9000"
```

**Note:** With Ambient, mTLS is enforced by ztunnel at the node level — no additional chart configuration is needed for service-to-service encryption.

---

## Performance tuning

**JVM memory:** Set `MaxRAMPercentage` relative to the container memory limit:

```yaml
resources:
  limits:
    memory: 4Gi
keycloak:
  javaOpts: "-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

**Database connection pool:** Tune via `extraEnv`:

```yaml
keycloak:
  extraEnv:
    - name: KC_DB_POOL_MAX_SIZE
      value: "30"
    - name: KC_DB_POOL_MIN_SIZE
      value: "5"
```

**Cache owners:** For full redundancy set `cache.owners` equal to `replicaCount`. For large deployments, `owners: 2` reduces replication overhead while maintaining one-node-failure tolerance.

**Termination grace period:** Increase for clusters with large session caches (>1 GB) to allow Infinispan to rebalance before pod exit:

```yaml
terminationGracePeriodSeconds: 120
```

---

## Testing

This chart ships with two `helm test` suites that run automatically as part of `ct install` in CI:

| Test pod | What it validates |
|----------|------------------|
| `<release>-test-connection` | TCP connectivity to the HTTP service port |
| `<release>-test-smoke` | Full OIDC token flow end-to-end |

**Run tests against a live release:**

```bash
helm test keycloak -n keycloak
```

**Smoke test coverage** (16 checks):

1. Management health endpoints: `/health/ready`, `/health/live` on port 9000
2. Admin token acquisition (master realm)
3. Realm create and verify in list
4. Public OIDC client creation with `directAccessGrantsEnabled` and `defaultClientScopes`
5. User creation with full profile (`firstName`, `lastName`, `email`, `emailVerified: true`)
6. Password set via reset-password API
7. OIDC direct grant with `scope=openid` — validates `access_token`, `id_token`, `refresh_token`
8. Userinfo endpoint (HTTP 200)
9. Token refresh
10. Logout / session revocation
11. Realm cleanup

All test pods run under PSA restricted mode (`readOnlyRootFilesystem: true`, `runAsNonRoot: true`, `capabilities.drop: ALL`).

**CI test profiles** (in `ci/`):

| File | Purpose |
|------|---------|
| `ci/default-values.yaml` | Minimal install for `ct install` — single replica, CI database |
| `ci/ha-values.yaml` | 3-replica HA mode |
| `ci/soc2-values.yaml` | SOC2/DPDP settings — audit logging on, PII masking enabled |

---

## Troubleshooting

**Pod stuck in `Pending`:** Check PVC binding (`kubectl describe pvc -n keycloak`) and node resource availability.

**Pod stuck in `Init:0/1`:** The DB checker init container cannot reach PostgreSQL. Verify `database.host`, port, and credentials. Temporarily disable with `dbchecker.enabled: false` to bypass.

**Startup probe failing — `connection refused` on port 9000:** Verify `KC_HEALTH_ENABLED=true` is being passed (this chart sets it unconditionally — check `kubectl describe pod` env section). Ensure port 9000 is not blocked by a NetworkPolicy or security group.

**Startup probe failing — timeout on large realm import:** Large realm imports can exceed the default 315 s window. Increase `startupProbe.failureThreshold`:

```yaml
startupProbe:
  failureThreshold: 120  # 120 × 5s = 600s
```

**`readOnlyRootFilesystem` crash loop:** Quarkus writes to `/opt/keycloak/lib/quarkus/` at startup. This chart handles it via an `init-quarkus` init container. If you see this crash with a custom base image, verify the init container copies the correct quarkus lib path.

**JGroups clustering not forming:** Ensure the NetworkPolicy allows inter-pod traffic on ports 7800 and 57800. Verify `cache.stack: kubernetes` and that the headless Service is reachable. Confirm pods are in the same namespace and service DNS resolves.

**503 from ingress:** Keycloak is not yet ready. Add `nginx.ingress.kubernetes.io/proxy-read-timeout: "600"` for slow-starting clusters. Check `kubectl get endpoints -n keycloak` to confirm pods are in the Ready state.

**Admin console shows wrong URL:** Set `proxy.mode: xforwarded` (nginx) or `forwarded` (RFC 7239 proxies) and ensure your ingress passes `X-Forwarded-*` headers.

**`invalid_redirect_uri` errors:** Set `proxy.hostnameStrict: "true"` and configure `KC_HOSTNAME` via `keycloak.extraEnv`.

**`helm test` smoke failing — "Account is not fully set up":** Keycloak 26.x `VERIFY_PROFILE` authenticator requires users to have `firstName`, `lastName`, `email`, and `emailVerified: true` before a direct grant succeeds. The smoke test creates users with all fields set — if you see this in your own tests, ensure user profiles are complete.

---

## Upgrading

### 0.3.3 (current)

**`init-quarkus` init container added (non-breaking rolling restart):**
All pods will restart during upgrade. An `init-quarkus` init container now copies the Quarkus lib to a writable emptyDir so `readOnlyRootFilesystem: true` works correctly. No data loss occurs.

**`KC_HEALTH_ENABLED` now set unconditionally:**
If you had this in `keycloak.extraEnv` already, remove the duplicate.

**Management port (9000) added to main Service:**
Additive change — the Service now exposes three ports instead of two. No existing tooling breaks.

**JGroups ports corrected to 7800/57800:**
If you have custom NetworkPolicy rules or external tooling referencing port 7600, update to 7800/57800. Keycloak 25+ does not use 7600.

### 0.2.x → 0.3.x

`appVersion` bumped from 25.x to 26.x. Keycloak 26 introduced stricter profile validation for direct grant flows — users must have `firstName`, `lastName`, `email`, and `emailVerified: true` set. Review and update existing test users if using direct grant.

---

## Production checklist

- [ ] Use `keycloak.auth.existingSecret` — do not store admin password in values or `--set` flags
- [ ] Use `database.existingSecret` — do not store DB password in values or `--set` flags
- [ ] Set `replicaCount: 3` minimum
- [ ] Enable `dbchecker.enabled: true` for reliable cold-start ordering
- [ ] Configure `ingress` with TLS (cert-manager recommended)
- [ ] Review NetworkPolicy rules — add `networkPolicy.extraIngress` for your ingress controller namespace
- [ ] Enable `metrics.serviceMonitor.enabled: true` if using Prometheus Operator
- [ ] Pin image to digest: `image.digest: "sha256:<digest>"`
- [ ] Set `soc2.auditLogging.enabled: true` for structured audit events
- [ ] Run `helm test <release> -n <namespace>` after every install or upgrade

---

## Support

- Issues: [github.com/arieotech/helm-charts/issues](https://github.com/arieotech/helm-charts/issues)
- Keycloak documentation: [keycloak.org/documentation](https://www.keycloak.org/documentation)
- Production support: [arieotech.com](https://arieotech.com)
