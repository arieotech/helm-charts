# Keycloak

Production-grade Helm chart for [Keycloak](https://www.keycloak.org/) — the open-source IAM and SSO platform.

**HA clustering · PSA restricted-mode · SOC2/DPDP defaults · JSON Schema validation · NetworkPolicy**

## Why this chart exists

The official `keycloak/keycloak` chart has significant production gaps this chart resolves:

- No NetworkPolicy (default open networking)
- No PSA restricted-mode support
- No JSON Schema validation — bad values silently ignored
- No SOC2/DPDP compliance defaults
- No startup probe tuned for large realm imports

## Quick start

```bash
helm repo add arieotech https://charts.arieotech.com
helm repo update

helm install keycloak arieotech/keycloak \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword=<admin-password> \
  --set database.host=<postgres-host> \
  --set database.password=<db-password>
```

## Prerequisites

- Kubernetes 1.27+
- Helm 3.12+
- PostgreSQL 15+ (external) — bundled PostgreSQL available for development only
- cert-manager (for TLS — recommended)
- Prometheus Operator (for ServiceMonitor — optional)

## Uninstalling the chart

```bash
helm uninstall keycloak --namespace keycloak
```

Note: PersistentVolumeClaims created for themes/providers are not deleted automatically. Remove them manually if no longer needed:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=keycloak -n keycloak
```

## Accessing Keycloak

**Via Ingress (production):**

Set `ingress.enabled=true` and configure a hostname — see [Ingress & TLS](#ingress--tls) below.

**Via port-forward (local testing):**

```bash
kubectl port-forward -n keycloak svc/keycloak 8080:80
```

Admin console: `http://localhost:8080/admin`

Default admin user: `admin` (set via `keycloak.auth.adminUser`)

## Configuration

### Image

| Key | Default | Description |
|-----|---------|-------------|
| `image.registry` | `quay.io` | Image registry |
| `image.repository` | `keycloak/keycloak` | Image repository |
| `image.tag` | `26.6.2` | Image tag |
| `image.digest` | `""` | Pin to digest (takes precedence over tag — recommended for production) |
| `image.pullPolicy` | `IfNotPresent` | Pull policy |
| `global.imagePullSecrets` | `[]` | Image pull secrets applied to all pods |

**Pin to digest in production:**

```yaml
image:
  tag: "26.6.2"
  digest: "sha256:<digest>"  # overrides tag
```

### Replicas and HA

| Key | Default | Description |
|-----|---------|-------------|
| `replicaCount` | `3` | Pod replicas. Minimum 3 for HA |
| `autoscaling.enabled` | `false` | Enable HPA |
| `autoscaling.minReplicas` | `3` | HPA minimum replicas |
| `autoscaling.maxReplicas` | `10` | HPA maximum replicas |
| `autoscaling.targetCPUUtilizationPercentage` | `70` | HPA CPU target |
| `pdb.enabled` | `true` | Enable PodDisruptionBudget |
| `pdb.minAvailable` | `1` | Minimum available pods during disruptions |
| `terminationGracePeriodSeconds` | `60` | Grace period — allows Infinispan to rebalance before exit |

### Admin credentials

| Key | Default | Description |
|-----|---------|-------------|
| `keycloak.auth.adminUser` | `admin` | Admin username |
| `keycloak.auth.adminPassword` | `""` | Admin password (dev only — use `existingSecret` in production) |
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

### Database

Keycloak requires PostgreSQL. The `bundled.enabled` option is for development only.

| Key | Default | Description |
|-----|---------|-------------|
| `database.vendor` | `postgres` | DB vendor: `postgres`, `mysql`, `mariadb` |
| `database.host` | `""` | PostgreSQL hostname (required) |
| `database.port` | `5432` | PostgreSQL port |
| `database.name` | `keycloak` | Database name |
| `database.username` | `keycloak` | Database username |
| `database.password` | `""` | Database password (dev only) |
| `database.existingSecret` | `""` | Name of existing Secret containing DB password |
| `database.existingSecretKey` | `db-password` | Key inside the existing Secret |

**Production pattern (existing secret):**

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

**DB checker init container** — waits for PostgreSQL before Keycloak starts:

```yaml
dbchecker:
  enabled: true
```

### Proxy and hostname

| Key | Default | Description |
|-----|---------|-------------|
| `proxy.mode` | `xforwarded` | `KC_PROXY_HEADERS`: `xforwarded` (nginx/ALB) or `forwarded` (RFC 7239) |
| `proxy.hostnameStrict` | `"false"` | `KC_HOSTNAME_STRICT`: reject requests for unknown hostnames |
| `proxy.http.enabled` | `true` | Enable HTTP listener (set `false` for end-to-end TLS) |

### Ingress & TLS

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

### Cache / clustering

Keycloak uses Infinispan for distributed session storage. JGroups DNS discovery requires stable pod names — the chart uses a StatefulSet for this reason.

| Key | Default | Description |
|-----|---------|-------------|
| `cache.stack` | `kubernetes` | Discovery: `kubernetes` (DNS), `tcp`, `udp` |
| `cache.owners` | `2` | Replicas holding a copy of each session entry |

```yaml
replicaCount: 3
cache:
  stack: kubernetes
  owners: 2
```

### Service

| Key | Default | Description |
|-----|---------|-------------|
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | HTTP service port |
| `service.httpsPort` | `443` | HTTPS service port |
| `service.annotations` | `{}` | Annotations (e.g. AWS NLB) |

### Persistence

Used for custom themes and provider JARs. Disabled by default — use `extraVolumes` for read-only providers.

| Key | Default | Description |
|-----|---------|-------------|
| `persistence.enabled` | `false` | Enable PVC for themes/providers |
| `persistence.size` | `1Gi` | PVC size |
| `persistence.storageClass` | `""` | Storage class (cluster default if empty) |
| `global.storageClass` | `""` | Global storage class override |

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

### Resources

| Key | Default | Description |
|-----|---------|-------------|
| `resources.requests.cpu` | `500m` | CPU request |
| `resources.requests.memory` | `1Gi` | Memory request |
| `resources.limits.memory` | `2Gi` | Memory limit (no CPU limit — prevents token validation throttling) |

### JVM options

```yaml
keycloak:
  javaOpts: "-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

### Probes

| Key | Default | Description |
|-----|---------|-------------|
| `startupProbe.initialDelaySeconds` | `15` | Startup probe delay |
| `startupProbe.periodSeconds` | `5` | Startup probe period |
| `startupProbe.failureThreshold` | `60` | Max failures (60 × 5s = 315s window for large realm imports) |
| `livenessProbe.initialDelaySeconds` | `60` | Liveness probe delay |
| `livenessProbe.failureThreshold` | `6` | Liveness failure threshold |
| `readinessProbe.initialDelaySeconds` | `30` | Readiness probe delay |
| `readinessProbe.failureThreshold` | `3` | Readiness failure threshold |

All probes use the Keycloak management port `9000` (`/health/live`, `/health/ready`, `/health/started`).

### ServiceAccount

| Key | Default | Description |
|-----|---------|-------------|
| `serviceAccount.create` | `true` | Create a dedicated ServiceAccount |
| `serviceAccount.name` | `""` | Override name (auto-generated if empty) |
| `serviceAccount.annotations` | `{}` | Annotations (e.g. IAM role for IRSA) |
| `serviceAccount.automountServiceAccountToken` | `false` | Do not auto-mount token |

### Pod scheduling

| Key | Default | Description |
|-----|---------|-------------|
| `nodeSelector` | `{}` | Node selector |
| `tolerations` | `[]` | Pod tolerations |
| `affinity` | `{}` | Pod affinity/anti-affinity rules |
| `priorityClassName` | `""` | Priority class name |
| `topologySpreadConstraints` | node + zone spread | Spread replicas across nodes and AZs |

Default topology spread (node + zone):

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
```

### Pod annotations and labels

```yaml
podAnnotations:
  prometheus.io/scrape: "true"
podLabels:
  team: platform
```

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
    image: fluentd:latest
```

### Realm import

Mount a realm JSON and auto-import on first startup. Keycloak skips import if the realm already exists (idempotent).

```yaml
realmImport:
  enabled: true
  realms:
    my-realm: |
      {
        "realm": "my-realm",
        "enabled": true
      }
```

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

### Keycloak features

```yaml
keycloak:
  features:
    tokenExchange: true          # Required for external IdP federation
    adminFineGrainedAuthz: true  # Fine-grained admin permissions
```

## NetworkPolicy

NetworkPolicy is **enabled by default** with a deny-all base and explicit allow-list:

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

## Metrics

| Key | Default | Description |
|-----|---------|-------------|
| `metrics.enabled` | `true` | Enable `/metrics` endpoint on port 9000 |
| `metrics.serviceMonitor.enabled` | `false` | Create Prometheus ServiceMonitor |
| `metrics.serviceMonitor.namespace` | `""` | Namespace for ServiceMonitor (default: release namespace) |
| `metrics.serviceMonitor.interval` | `30s` | Scrape interval |
| `metrics.prometheusRule.enabled` | `false` | Create PrometheusRule |

```yaml
metrics:
  serviceMonitor:
    enabled: true
    labels:
      prometheus: kube-prometheus
```

## Production checklist

- [ ] Use `keycloak.auth.existingSecret` — do not store admin password in values
- [ ] Use `database.existingSecret` — do not store DB password in values
- [ ] Set `replicaCount: 3` minimum
- [ ] Configure `ingress` with TLS (cert-manager recommended)
- [ ] Enable `metrics.serviceMonitor.enabled: true` if using Prometheus Operator
- [ ] Review NetworkPolicy rules — add `extraIngress` for your ingress controller namespace
- [ ] Enable `dbchecker.enabled: true` for reliable cold-start ordering
- [ ] Pin image to digest: `image.digest: "sha256:<digest>"`
- [ ] Set `soc2.auditLogging.enabled: true` for audit events

## SOC2 compliance

```yaml
soc2:
  auditLogging:
    enabled: true   # Structured JSON audit events to stdout
  enforceTLS: true  # Reject plaintext connections
```

## DPDP compliance (India)

```yaml
dpdp:
  piiMasking:
    enabled: true   # Mask email/name fields in Keycloak logs
  dataResidency:
    enabled: true
    region: "ap-south-1"  # Triggers namespace annotation for OPA/Kyverno policy
```

## Using External Secrets Operator

```yaml
keycloak:
  auth:
    existingSecret: keycloak-admin
    existingSecretKey: admin-password

database:
  existingSecret: keycloak-db
  existingSecretKey: db-password
```

Create the secrets via ESO `ExternalSecret` resources pointing to your vault.

## Performance tuning

**JVM memory:** Set `MaxRAMPercentage` relative to the container memory limit:

```yaml
resources:
  limits:
    memory: 4Gi
keycloak:
  javaOpts: "-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

**Database connection pool:** Tune `KC_DB_POOL_MAX_SIZE` via `extraEnv`:

```yaml
keycloak:
  extraEnv:
    - name: KC_DB_POOL_MAX_SIZE
      value: "30"
    - name: KC_DB_POOL_MIN_SIZE
      value: "5"
```

**Cache owners:** For full redundancy set `cache.owners` equal to `replicaCount`. For large deployments, `owners: 2` reduces replication overhead while maintaining one-node-failure tolerance.

**Termination grace period:** Increase for clusters with large caches (> 1 GB session data) to allow Infinispan to rebalance before pod exit:

```yaml
terminationGracePeriodSeconds: 120
```

## Troubleshooting

**Pod stuck in `Pending`:** Check PVC binding (`kubectl describe pvc -n keycloak`) and node resource availability.

**Pod stuck in `Init:0/1`:** DB checker init container cannot reach PostgreSQL. Verify `database.host`, port, and credentials. Temporarily disable with `dbchecker.enabled: false` to bypass.

**Startup probe failing:** Large realm imports can exceed the default 315s window. Increase `startupProbe.failureThreshold`:

```yaml
startupProbe:
  failureThreshold: 120  # 120 × 5s = 600s
```

**JGroups clustering not forming:** Ensure NetworkPolicy allows inter-pod traffic on ports 7800 and 57800. Verify `cache.stack: kubernetes` and that the headless Service is reachable.

**503 from ingress:** Check readiness probe — Keycloak is not ready yet. Add `nginx.ingress.kubernetes.io/proxy-read-timeout: "600"` annotation for slow-starting clusters.

**Admin console shows wrong URL:** Set `proxy.mode: xforwarded` (nginx) or `forwarded` (RFC 7239 proxies) and ensure your ingress passes `X-Forwarded-*` headers.

**`invalid_redirect_uri` errors:** Set `proxy.hostnameStrict: "true"` and configure `KC_HOSTNAME` via `keycloak.extraEnv`.

## Support

- Issues: [github.com/arieotech/helm-charts/issues](https://github.com/arieotech/helm-charts/issues)
- Keycloak documentation: [keycloak.org/documentation](https://www.keycloak.org/documentation)
- Production support: [arieotech.com](https://arieotech.com)
