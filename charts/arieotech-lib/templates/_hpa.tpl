{{/*
HorizontalPodAutoscaler (autoscaling/v2).
Enabled via autoscaling.enabled=true. Requires metrics-server.
*/}}
{{- define "arieotech.hpa" -}}
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "arieotech.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "arieotech.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: {{ .Values.autoscaling.kind | default "Deployment" }}
    name: {{ include "arieotech.fullname" . }}
  minReplicas: {{ default 1 .Values.autoscaling.minReplicas }}
  maxReplicas: {{ default 3 .Values.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
{{- end }}
