{{/*
PodDisruptionBudget — enabled by default when replicaCount > 1.
Defaults to minAvailable: 1. Override with pdb.minAvailable or pdb.maxUnavailable.
*/}}
{{- define "arieotech.pdb" -}}
{{- if and .Values.pdb.enabled (gt (int .Values.replicaCount) 1) }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "arieotech.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "arieotech.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "arieotech.selectorLabels" . | nindent 6 }}
  {{- if .Values.pdb.maxUnavailable }}
  maxUnavailable: {{ .Values.pdb.maxUnavailable }}
  {{- else }}
  minAvailable: {{ default 1 .Values.pdb.minAvailable }}
  {{- end }}
{{- end }}
{{- end }}
