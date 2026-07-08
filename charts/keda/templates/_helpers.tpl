{{- define "keda.name" -}}
{{- include "arieotech.name" . }}
{{- end }}

{{- define "keda.fullname" -}}
{{- include "arieotech.fullname" . }}
{{- end }}

{{- define "keda.chart" -}}
{{- include "arieotech.chart" . }}
{{- end }}

{{- define "keda.labels" -}}
{{- include "arieotech.labels" . }}
{{- end }}

{{- define "keda.selectorLabels" -}}
{{- include "arieotech.selectorLabels" . }}
{{- end }}

{{- define "keda.serviceAccountName" -}}
{{- include "arieotech.serviceAccountName" . }}
{{- end }}

{{/*
Operator component selector labels — used by the operator Deployment and Service.
*/}}
{{- define "keda.operatorSelectorLabels" -}}
{{ include "keda.selectorLabels" . }}
app.kubernetes.io/component: operator
{{- end }}

{{/*
Metrics API Server component selector labels.
*/}}
{{- define "keda.metricsSelectorLabels" -}}
{{ include "keda.selectorLabels" . }}
app.kubernetes.io/component: metrics-apiserver
{{- end }}

{{/*
Admission Webhooks component selector labels.
*/}}
{{- define "keda.webhooksSelectorLabels" -}}
{{ include "keda.selectorLabels" . }}
app.kubernetes.io/component: admission-webhooks
{{- end }}

{{/*
Render an image reference for a component-specific image block.
Accepts a dict with keys: registry, repository, tag, digest.
*/}}
{{- define "keda.componentImage" -}}
{{- $img := . -}}
{{- if $img.digest -}}
{{ $img.registry }}/{{ $img.repository }}@{{ $img.digest }}
{{- else -}}
{{ $img.registry }}/{{ $img.repository }}:{{ $img.tag }}
{{- end -}}
{{- end }}

{{/*
NetworkPolicy egress rule for the Kubernetes API server. Restricted to
networkPolicy.kubeApiServerCIDR when set; otherwise port-only (Kubernetes
NetworkPolicy has no generic pod/namespace selector for the API server, since it
typically runs outside the pod network) — see the comment in values.yaml.
*/}}
{{- define "keda.kubeApiServerEgressRule" -}}
{{- if .Values.networkPolicy.kubeApiServerCIDR }}
- to:
    - ipBlock:
        cidr: {{ .Values.networkPolicy.kubeApiServerCIDR }}
  ports:
    - port: 6443
      protocol: TCP
    - port: 443
      protocol: TCP
{{- else }}
## Port-only: allows HTTPS egress to ANY destination on 443/6443, not just the API
## server. Set networkPolicy.kubeApiServerCIDR to restrict this.
- ports:
    - port: 6443
      protocol: TCP
    - port: 443
      protocol: TCP
{{- end }}
{{- end }}
