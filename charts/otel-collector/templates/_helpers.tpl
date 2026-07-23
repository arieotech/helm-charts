{{- define "otel-collector.name" -}}
{{- include "arieotech.name" . }}
{{- end }}

{{- define "otel-collector.fullname" -}}
{{- include "arieotech.fullname" . }}
{{- end }}

{{- define "otel-collector.chart" -}}
{{- include "arieotech.chart" . }}
{{- end }}

{{- define "otel-collector.labels" -}}
{{- include "arieotech.labels" . }}
{{- end }}

{{- define "otel-collector.selectorLabels" -}}
{{- include "arieotech.selectorLabels" . }}
{{- end }}

{{- define "otel-collector.serviceAccountName" -}}
{{- include "arieotech.serviceAccountName" . }}
{{- end }}

{{/*
Determine the workload kind: Deployment or DaemonSet.
Valid values: deployment, daemonset. Defaults to Deployment.
*/}}
{{- define "otel-collector.workloadKind" -}}
{{- if eq .Values.mode "daemonset" -}}
DaemonSet
{{- else -}}
Deployment
{{- end -}}
{{- end }}

{{/*
ConfigMap name for the collector pipeline configuration.
*/}}
{{- define "otel-collector.configMapName" -}}
{{- printf "%s-config" (include "otel-collector.fullname" .) }}
{{- end }}
