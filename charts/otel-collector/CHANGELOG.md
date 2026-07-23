# Changelog

All notable changes to the `otel-collector` chart will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Chart versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] — 2026-07-22

### Added
- Initial release of the Arieotech OpenTelemetry Collector chart.
- Uses `otel/opentelemetry-collector-contrib:0.154.0` — the complete distribution
- Collector 0.129+ compatibility: no `memory_ballast` extension (removed upstream —
  use the `memory_limiter` processor and GOMEMLIMIT via extraEnv), and internal
  telemetry metrics use the `readers` syntax (`service::telemetry::metrics::address`
  was deprecated in v0.111.0)
- Default pipelines use the `debug` exporter so a fresh install starts cleanly with
  no external backend; an `otlp` exporter with an empty endpoint fails collector
  startup and is deliberately not shipped
  (fixes upstream issue #1055 which ships an incomplete default image).
- Supports both `Deployment` (central gateway) and `DaemonSet` (node agent) modes
  via the `mode` value.
- Full JSON Schema validation (`values.schema.json`) — rejects `latest` image tags.
- PSA restricted-mode security: `runAsNonRoot`, `readOnlyRootFilesystem`,
  `capabilities.drop: ALL`, `seccompProfile: RuntimeDefault`.
- NetworkPolicy enabled by default: allow OTLP (4317, 4318), metrics (8888),
  health (13133); deny-all otherwise.
- PodDisruptionBudget (enabled by default, gated on replicaCount > 1).
- HorizontalPodAutoscaler (opt-in, Deployment mode only).
- Prometheus Operator ServiceMonitor (opt-in).
- PrometheusRule with alerts: `OtelCollectorDown`, `OtelCollectorHighDroppedSpans`,
  `OtelCollectorHighDroppedMetricPoints`, `OtelCollectorExporterFailures`,
  `OtelCollectorHighMemoryUsage`.
- ConfigMap-based pipeline configuration — all OTel Collector YAML rendered via
  `values.config`; checksum annotation triggers rolling restart on config change.
- Istio Ambient Mesh support: `istio.io/dataplane-mode: ambient` pod label,
  ztunnel port exclusion annotation.
- SOC2 compliance: structured JSON logging enforced when `soc2.auditLogging.enabled`.
- DPDP compliance: PII masking toggle, data residency namespace annotation.
- `ci/default-values.yaml` — debug exporter (no backend required for ct install).
- `ci/ha-values.yaml` — 3-replica HA with autoscaling and ServiceMonitor.
- `ci/istio-ambient-values.yaml` — Istio Ambient with ztunnel exclusions.
- `helm test` suite: health check and metrics endpoint connectivity tests.
- Artifact Hub metadata complete.

[0.1.0]: https://github.com/arieotech/helm-charts/releases/tag/otel-collector-0.1.0
