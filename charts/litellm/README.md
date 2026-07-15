# Arieotech LiteLLM Helm Chart

Production-grade [LiteLLM 1.92.0](https://litellm.ai) AI gateway chart — the first production Helm chart for LiteLLM.

**Arieotech differentiator:** Ships with DPDP (India Digital Personal Data Protection Act) PII-stripping enabled by default, making it the only LiteLLM chart suitable for regulated AI workloads in India and markets with similar data residency requirements.

## What is LiteLLM?

LiteLLM is an AI gateway that provides a unified OpenAI-compatible API endpoint routing to 100+ LLM providers:

- **OpenAI** — GPT-4o, o-series
- **Anthropic** — Claude Sonnet and Opus families
- **AWS Bedrock** — Llama, Mistral, Amazon Nova
- **Google Vertex AI** — Gemini Pro/Ultra
- **Azure OpenAI**
- **Ollama** (local models)
- And 100+ others

## Market Gap

No production Helm chart for LiteLLM exists. The official repository has only a basic `docker-compose.yml`. This Arieotech chart ships:
- PSA restricted-mode compatible (non-root, read-only filesystem)
- NetworkPolicy enabled by default
- DPDP PII-stripping defaults
- SOC2 structured JSON logging
- Prometheus ServiceMonitor + PrometheusRule alerting
- PodDisruptionBudget for HA
- HPA for autoscaling

## Prerequisites

- Kubernetes >= 1.27
- LLM provider API keys (stored in Kubernetes Secrets)
- (Optional) External PostgreSQL for spend tracking and user management
- (Optional) External Redis for cross-replica usage-based routing

## Quick Start

```bash
helm repo add arieotech https://arieotech.github.io/helm-charts
helm repo update

# Create provider keys secret
kubectl create secret generic llm-provider-keys \
  --from-literal=OPENAI_API_KEY=sk-... \
  --from-literal=ANTHROPIC_API_KEY=sk-ant-... \
  -n ai

# Install LiteLLM
helm install litellm arieotech/litellm \
  --namespace ai \
  --create-namespace \
  --set masterKey.value=sk-my-master-key \
  --set providerSecrets.existingSecret=llm-provider-keys \
  --set "providerSecrets.keys={OPENAI_API_KEY,ANTHROPIC_API_KEY}"
```

## Production Install

```bash
# Create master key secret
kubectl create secret generic litellm-master-key \
  --from-literal=master-key=sk-my-secure-master-key \
  -n ai

helm install litellm arieotech/litellm \
  --namespace ai \
  --create-namespace \
  --set replicaCount=2 \
  --set masterKey.existingSecret=litellm-master-key \
  --set providerSecrets.existingSecret=llm-provider-keys \
  --set "providerSecrets.keys={OPENAI_API_KEY,ANTHROPIC_API_KEY}" \
  --set database.enabled=true \
  --set database.existingSecret=litellm-db \
  --set redis.enabled=true \
  --set redis.host=redis.cache.svc.cluster.local \
  --set networkPolicy.enabled=true \
  --set metrics.serviceMonitor.enabled=true \
  --set metrics.prometheusRule.enabled=true \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=llm.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix
```

## Supported LLM Providers

| Provider | Config key | Notes |
|----------|-----------|-------|
| OpenAI | `openai/gpt-4o` | Requires `OPENAI_API_KEY` |
| Anthropic | `anthropic/claude-3-5-sonnet-20241022` | Requires `ANTHROPIC_API_KEY` |
| AWS Bedrock | `bedrock/anthropic.claude-3-5-sonnet...` | Requires `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| Azure OpenAI | `azure/<deployment>` | Requires `AZURE_API_KEY`, `AZURE_API_BASE` |
| Google Vertex AI | `vertex_ai/gemini-pro` | Requires `GOOGLE_APPLICATION_CREDENTIALS` |
| Ollama (local) | `ollama/<model>` | Requires `OLLAMA_API_BASE` |

## DPDP Compliance (India Data Protection)

When `dpdp.piiMasking.enabled: true` (default):
- `LITELLM_REDACT_USER_API_KEY_INFO=True` — strips API keys from logs
- `redact_messages_in_exceptions: true` — prevents prompt content from appearing in error logs
- Fields masked: email, phone_number, ip_address, credit_card_number

To add custom fields to scrub:

```yaml
dpdp:
  piiMasking:
    enabled: true
    scrubFields:
      - email
      - phone_number
      - pan_number      # India PAN card
      - aadhaar_number  # India Aadhaar
```

## Model Configuration

Edit `config.model_list` in values to define your routes:

```yaml
config:
  model_list:
    - model_name: gpt-4o
      litellm_params:
        model: openai/gpt-4o
        api_key: "os.environ/OPENAI_API_KEY"
    - model_name: claude-sonnet
      litellm_params:
        model: anthropic/claude-3-5-sonnet-20241022
        api_key: "os.environ/ANTHROPIC_API_KEY"
    ## Load-balance across providers
    - model_name: fast-llm
      litellm_params:
        model: openai/gpt-4o-mini
        api_key: "os.environ/OPENAI_API_KEY"
      model_info:
        mode: chat
    - model_name: fast-llm
      litellm_params:
        model: anthropic/claude-3-haiku-20240307
        api_key: "os.environ/ANTHROPIC_API_KEY"
```

## Production Checklist

- [ ] `masterKey.existingSecret` set (never plaintext in production)
- [ ] `providerSecrets.existingSecret` set with all API keys
- [ ] `replicaCount: 2` minimum
- [ ] `pdb.enabled: true`
- [ ] `networkPolicy.enabled: true`
- [ ] `database.enabled: true` with external PostgreSQL (for spend tracking)
- [ ] `redis.enabled: true` with external Redis (for cross-replica routing)
- [ ] `metrics.serviceMonitor.enabled: true`
- [ ] `metrics.prometheusRule.enabled: true`
- [ ] `dpdp.piiMasking.enabled: true` (already default)
- [ ] `soc2.auditLogging.enabled: true` (already default)
- [ ] Image digest pinned (`image.digest: sha256:...`)
- [ ] Ingress TLS configured

## Values Reference

| Parameter | Default | Description |
|-----------|---------|-------------|
| `image.tag` | `v1.92.0` | LiteLLM version |
| `replicaCount` | `2` | Number of replicas |
| `masterKey.value` | `""` | Master key (use existingSecret in prod) |
| `dpdp.piiMasking.enabled` | `true` | DPDP PII stripping |
| `redis.enabled` | `false` | Enable Redis for cross-replica routing |
| `database.enabled` | `false` | Enable PostgreSQL for spend tracking |
| `networkPolicy.enabled` | `true` | Deny-all with allow-list |
| `metrics.enabled` | `true` | Prometheus metrics |

See [values.yaml](values.yaml) for the full reference.
