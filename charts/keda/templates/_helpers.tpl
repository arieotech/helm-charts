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
