{{/*
Prometheus Operator ServiceMonitor.
Requires prometheus-operator CRDs to be installed.
Enabled via metrics.serviceMonitor.enabled=true.
*/}}
{{- define "arieotech.serviceMonitor" -}}
{{- if and .Values.metrics.enabled .Values.metrics.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "arieotech.fullname" . }}
  namespace: {{ default .Release.Namespace .Values.metrics.serviceMonitor.namespace }}
  labels:
    {{- include "arieotech.labels" . | nindent 4 }}
    {{- with .Values.metrics.serviceMonitor.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  selector:
    matchLabels:
      {{- include "arieotech.selectorLabels" . | nindent 6 }}
  endpoints:
    - port: {{ default "metrics" .Values.metrics.serviceMonitor.port }}
      path: {{ default "/metrics" .Values.metrics.serviceMonitor.path }}
      interval: {{ default "30s" .Values.metrics.serviceMonitor.interval }}
      scrapeTimeout: {{ default "10s" .Values.metrics.serviceMonitor.scrapeTimeout }}
      {{- with .Values.metrics.serviceMonitor.relabelings }}
      relabelings:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.metrics.serviceMonitor.metricRelabelings }}
      metricRelabelings:
        {{- toYaml . | nindent 8 }}
      {{- end }}
  namespaceSelector:
    matchNames:
      - {{ .Release.Namespace }}
{{- end }}
{{- end }}
