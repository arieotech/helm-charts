# Keycloak

Production-grade Helm chart for [Keycloak](https://www.keycloak.org/) — the open-source IAM and SSO platform.

**HA clustering · PSA restricted-mode · SOC2/DPDP defaults · JSON Schema validation**

## Why this chart exists

The official `keycloak/keycloak` chart has significant production gaps this chart resolves:

- No NetworkPolicy (default open networking)
- No PSA restricted-mode support
- No JSON Schema validation
- No SOC2/DPDP compliance defaults

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

## Production checklist

Before going to production:

- [ ] Use `keycloak.auth.existingSecret` instead of `adminPassword` in values
- [ ] Use `database.existingSecret` instead of `database.password` in values
- [ ] Set `replicaCount: 3` minimum
- [ ] Configure `ingress` with TLS
- [ ] Enable `metrics.serviceMonitor.enabled: true` if using Prometheus Operator
- [ ] Review NetworkPolicy rules — add `extraIngress` for your ingress controller namespace
- [ ] Pin image to digest: `image.tag: "25.0.6@sha256:<digest>"`

## HA configuration

Keycloak uses Infinispan for distributed session storage. The chart defaults to `cache.stack: kubernetes` which uses JGroups DNS discovery via the headless Service.

```yaml
replicaCount: 3
cache:
  stack: kubernetes
  owners: 2  # Each session cached on 2 replicas
```

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

## NetworkPolicy

NetworkPolicy is **enabled by default** with a deny-all base and explicit allow-list for:
- HTTP/HTTPS ingress
- Management port 9000 (health checks)
- JGroups ports 7600/57600 (inter-pod clustering)
- PostgreSQL egress on `database.port`
- DNS egress (always)

To allow ingress from your ingress-nginx namespace:
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

## Values reference

| Key | Default | Description |
|-----|---------|-------------|
| `replicaCount` | `3` | Pod replicas. Minimum 3 for HA. |
| `image.repository` | `quay.io/keycloak/keycloak` | Image repository |
| `image.tag` | `25.0.6` | Image tag |
| `keycloak.auth.adminUser` | `admin` | Admin username |
| `keycloak.auth.adminPassword` | `""` | Admin password (use existingSecret in production) |
| `database.vendor` | `postgres` | DB vendor: postgres, mysql, mariadb |
| `database.host` | `""` | PostgreSQL hostname (required) |
| `database.bundled.enabled` | `false` | Use bundled PostgreSQL (dev only) |
| `cache.stack` | `kubernetes` | Infinispan discovery: kubernetes, tcp, udp |
| `networkPolicy.enabled` | `true` | Enable NetworkPolicy |
| `pdb.enabled` | `true` | Enable PodDisruptionBudget |
| `metrics.serviceMonitor.enabled` | `false` | Create Prometheus ServiceMonitor |
| `soc2.auditLogging.enabled` | `true` | Structured audit logging |
| `dpdp.piiMasking.enabled` | `false` | PII masking in logs |

Full values reference: [values.yaml](values.yaml) | [values.schema.json](values.schema.json)

## Support

- Issues: [github.com/arieotech/helm-charts/issues](https://github.com/arieotech/helm-charts/issues)
- Keycloak documentation: [keycloak.org/documentation](https://www.keycloak.org/documentation)
- Production support: [arieotech.com](https://arieotech.com)
