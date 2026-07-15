# LiteLLM Chart Changelog

All notable changes to the LiteLLM Helm chart are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.1.0] — 2026-07-13

### Added
- Initial release — first production Helm chart for LiteLLM 1.92.0
- Deployment with 2 replicas as production default
- PSA restricted-mode compatible (non-root, read-only root filesystem, drop ALL capabilities)
- ConfigMap-based config.yaml (fully templated from values including model_list)
- Secret management for master key, Redis password, and database URL
- Provider API keys via existingSecret + keys list (External Secrets Operator compatible)
- Service with HTTP (4000) and UI (4001) ports
- Ingress template with TLS support
- NetworkPolicy: deny-all with explicit egress to LLM provider APIs (HTTPS 443)
- PodDisruptionBudget (gated on pdb.enabled and replicaCount > 1)
- HPA (gated on autoscaling.enabled)
- ServiceMonitor template (Prometheus Operator)
- SOC2 audit logging via structured JSON logs to stdout (`JSON_LOGS=True` + `LITELLM_LOG=INFO`) —
  deliberately not `--detailed_debug`, which logs raw request/response bodies (PII leak) and degrades performance
- Fail-fast render-time validation: `masterKey.value` or `masterKey.existingSecret` is required
- PrometheusRule with alerts: LiteLLMDown, LiteLLMHighErrorRate, LiteLLMHighLatency, LiteLLMHighTokenUsage
- DPDP PII-stripping enabled by default (first LiteLLM chart with DPDP support)
- SOC2: structured JSON logging, TLS enforcement
- Istio Ambient Mesh label and port exclusion support
- `values.schema.json` with full validation (rejects `latest` tag, validates booleans)
- Helm test: liveness + readiness health endpoint checks
- ci/default-values.yaml, ci/ha-values.yaml
- Redis integration (external — points to existing Redis cluster)
- PostgreSQL integration (external — connection string via Secret)
