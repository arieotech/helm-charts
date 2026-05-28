{{/*
ServiceAccount render helper.
*/}}
{{- define "arieotech.serviceAccount" -}}
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "arieotech.serviceAccountName" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "arieotech.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ default false .Values.serviceAccount.automountServiceAccountToken }}
{{- end }}
{{- end }}
