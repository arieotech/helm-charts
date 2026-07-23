# otel-collector

Production-grade OpenTelemetry Collector Helm chart by [Arieotech](https://arieotech.com).

## Why this chart?

The upstream `opentelemetry-collector` chart ships an incomplete default image
([issue #1055](https://github.com/open-telemetry/opentelemetry-helm-charts/issues/1055)),
has no JSON Schema validation, and lacks Istio Ambient Mesh support. This chart fixes all three.

**Key differentiators:**

| Feature | Upstream chart | This chart |
|---------|---------------|------------|
| Default image | `otel/opentelemetry-collector` (core, missing receivers) | `otel/opentelemetry-collector-contrib` (full distribution) |
| JSON Schema | None | Full `values.schema.json`, rejects `latest` tags |
| Istio Ambient | Not supported | `istio.io/dataplane-mode: ambient` label + ztunnel exclusions |
| PSA restricted | Not enforced | All containers PSA restricted-compatible |
| NetworkPolicy | Opt-in, incomplete | Enabled by default, deny-all + allow-list |
| SOC2/DPDP | None | Structured JSON logging, PII masking toggle |

## Quick start

```bash
helm repo add arieotech https://arieotech.github.io/helm-charts
helm repo update
helm install otel-collector arieotech/otel-collector \
  --namespace observability \
  --create-namespace \
  --set config.exporters.otlp.endpoint=https://your-backend:4317
```

## Deployment modes

Set `mode: deployment` (default) for a central gateway or `mode: daemonset` for node-level agents.

```bash
## Node agent (DaemonSet)
helm install otel-node-agent arieotech/otel-collector \
  --set mode=daemonset \
  --set replicaCount=1
```

## Configuration

The collector pipeline is configured via `values.config`, which is rendered as YAML into a
ConfigMap and mounted read-only into the collector container. Changing any value under
`config.*` triggers an automatic rolling restart via ConfigMap checksum annotation.

Minimal production configuration:

```yaml
config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: "0.0.0.0:4317"
        http:
          endpoint: "0.0.0.0:4318"
  processors:
    memory_limiter:
      check_interval: 5s
      limit_percentage: 80
      spike_limit_percentage: 25
    batch:
      send_batch_size: 10000
      timeout: 10s
  exporters:
    otlp:
      endpoint: "https://your-signoz-or-jaeger:4317"
  extensions:
    health_check:
      endpoint: "0.0.0.0:13133"
  service:
    extensions: [health_check]
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlp]
      metrics:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlp]
      logs:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlp]
```

## Istio Ambient Mesh

```yaml
istio:
  ambient:
    enabled: true
    excludedPorts:
      - 13133  # health check — must reach kubelet directly
      - 8888   # self-metrics — must reach Prometheus directly
```

## ServiceMonitor (Prometheus Operator)

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    labels:
      release: kube-prometheus-stack
```

## SOC2 compliance

Enabled by default (`soc2.auditLogging.enabled: true`). Forces structured JSON log encoding
at INFO level minimum. Disable only in development:

```yaml
soc2:
  auditLogging:
    enabled: false
```

## DPDP compliance

Enable PII masking when processing logs that may contain personal data:

```yaml
dpdp:
  piiMasking:
    enabled: true
  dataResidency:
    enabled: true
    region: "ap-south-1"
```

When `piiMasking.enabled: true`, add a `transform` processor to your pipeline that
redacts known PII fields (email, IP addresses, user IDs) before export.

## Production checklist

- [ ] `config.exporters.otlp.endpoint` set to your observability backend
- [ ] `image.digest` set for immutable pinning (preferred over tag in production)
- [ ] `resources.requests` and `resources.limits` tuned for expected throughput
- [ ] `config.processors.memory_limiter.limit_percentage` tuned (default 80%)
- [ ] `replicaCount >= 2` (default) for HA in Deployment mode
- [ ] `pdb.enabled: true` (default)
- [ ] `networkPolicy.enabled: true` (default)
- [ ] `metrics.serviceMonitor.enabled: true` if using Prometheus Operator
- [ ] `metrics.prometheusRule.enabled: true` for alerting
- [ ] `soc2.auditLogging.enabled: true` (default)
- [ ] TLS configured on the OTLP exporter endpoint when `soc2.enforceTLS: true`

## Parameters

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `mode` | string | `deployment` | Workload type: `deployment` or `daemonset` |
| `replicaCount` | int | `2` | Replicas (ignored for daemonset) |
| `image.registry` | string | `docker.io` | Image registry |
| `image.repository` | string | `otel/opentelemetry-collector-contrib` | Image repository |
| `image.tag` | string | `0.154.0` | Image tag (latest rejected) |
| `image.digest` | string | `""` | Image digest (overrides tag) |
| `config` | object | see values.yaml | Full OTel Collector pipeline YAML |
| `ports.otlp.enabled` | bool | `true` | Enable OTLP gRPC port 4317 |
| `ports.otlpHttp.enabled` | bool | `true` | Enable OTLP HTTP port 4318 |
| `ports.metrics.enabled` | bool | `true` | Enable self-metrics port 8888 |
| `ports.healthCheck.enabled` | bool | `true` | Enable health check port 13133 |
| `networkPolicy.enabled` | bool | `true` | Enable deny-all NetworkPolicy |
| `pdb.enabled` | bool | `true` | Enable PodDisruptionBudget |
| `autoscaling.enabled` | bool | `false` | Enable HPA |
| `metrics.serviceMonitor.enabled` | bool | `false` | Enable Prometheus Operator ServiceMonitor |
| `metrics.prometheusRule.enabled` | bool | `false` | Enable PrometheusRule alerts |
| `istio.ambient.enabled` | bool | `false` | Enable Istio Ambient Mesh labels |
| `soc2.auditLogging.enabled` | bool | `true` | Enforce JSON structured logging |
| `soc2.enforceTLS` | bool | `true` | Enforce TLS on exporter connections |

## Source / Issues

- Chart source: https://github.com/arieotech/helm-charts/tree/main/charts/otel-collector
- OTel Collector docs: https://opentelemetry.io/docs/collector/
- Upstream issue (incomplete default image): https://github.com/open-telemetry/opentelemetry-helm-charts/issues/1055
