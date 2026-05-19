# Arieotech Helm Charts

Production-grade Helm charts for Kubernetes — security-hardened, compliance-ready, and built for real production workloads.

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/arieotech)](https://artifacthub.io/packages/search?repo=arieotech)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Release Charts](https://github.com/arieotech/helm-charts/actions/workflows/release.yaml/badge.svg)](https://github.com/arieotech/helm-charts/actions/workflows/release.yaml)

## What makes these charts different

Every chart ships with:
- **PSA restricted-mode compatible** — runs without `privileged` or `allowPrivilegeEscalation`
- **NetworkPolicy enabled by default** — deny-all with explicit allow-list, not opt-in
- **JSON Schema validation** — `helm install` fails fast on invalid values
- **SOC2 and DPDP compliance defaults** — audit logging, TLS options, PII controls baked in
- **Production-pinned images** — digest or semver, never `latest`

## Add the chart repository

```bash
helm repo add arieotech https://charts.arieotech.com
helm repo update
```

Or via OCI (GHCR):
```bash
helm install my-release oci://ghcr.io/arieotech/charts/<chart-name>
```

## Available charts

| Chart | Version | Description |
|-------|---------|-------------|
| [keycloak](charts/keycloak/) | 0.2.0 | IAM & SSO — HA, PSA restricted-mode, SOC2/DPDP, official Keycloak image |

## Arieotech Production Baseline

All charts comply with the [Production Baseline](docs/chart-standards.md):

- [ ] PSA restricted-mode compatible
- [ ] All containers run as non-root with `readOnlyRootFilesystem`
- [ ] No `latest` image tags — pinned to digest or semver
- [ ] NetworkPolicy shipped **and enabled by default**
- [ ] Resource requests and limits set
- [ ] `PodDisruptionBudget` for all stateful and critical workloads
- [ ] `ServiceMonitor` for Prometheus Operator
- [ ] JSON Schema validation for all values
- [ ] SOC2 audit logging hook
- [ ] DPDP data residency annotation support

## Contributing

See [CONTRIBUTING.md](docs/contributing.md) and [chart-standards.md](docs/chart-standards.md).

## License

Apache 2.0 — see [LICENSE](LICENSE).
