{{- define "keycloak.name" -}}
{{- include "arieotech.name" . }}
{{- end }}

{{- define "keycloak.fullname" -}}
{{- include "arieotech.fullname" . }}
{{- end }}

{{- define "keycloak.chart" -}}
{{- include "arieotech.chart" . }}
{{- end }}

{{- define "keycloak.labels" -}}
{{- include "arieotech.labels" . }}
{{- end }}

{{- define "keycloak.selectorLabels" -}}
{{- include "arieotech.selectorLabels" . }}
{{- end }}

{{- define "keycloak.serviceAccountName" -}}
{{- include "arieotech.serviceAccountName" . }}
{{- end }}

{{/*
Database secret name — prefer existingSecret over generated secret.
*/}}
{{- define "keycloak.databaseSecretName" -}}
{{- if .Values.database.existingSecret }}
{{- .Values.database.existingSecret }}
{{- else }}
{{- printf "%s-db" (include "keycloak.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Admin credentials secret name.
*/}}
{{- define "keycloak.adminSecretName" -}}
{{- if .Values.keycloak.auth.existingSecret }}
{{- .Values.keycloak.auth.existingSecret }}
{{- else }}
{{- printf "%s-admin" (include "keycloak.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Management port for health checks (not the HTTP port).
Keycloak 22+ exposes /health on port 9000 separate from the main HTTP port.
*/}}
{{- define "keycloak.managementPort" -}}
9000
{{- end }}
