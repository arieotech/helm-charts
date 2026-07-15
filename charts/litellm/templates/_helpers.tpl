{{- define "litellm.name" -}}
{{- include "arieotech.name" . }}
{{- end }}

{{- define "litellm.fullname" -}}
{{- include "arieotech.fullname" . }}
{{- end }}

{{- define "litellm.chart" -}}
{{- include "arieotech.chart" . }}
{{- end }}

{{- define "litellm.labels" -}}
{{- include "arieotech.labels" . }}
{{- end }}

{{- define "litellm.selectorLabels" -}}
{{- include "arieotech.selectorLabels" . }}
{{- end }}

{{- define "litellm.serviceAccountName" -}}
{{- include "arieotech.serviceAccountName" . }}
{{- end }}

{{/*
Name of the ConfigMap holding litellm_config.yaml.
*/}}
{{- define "litellm.configMapName" -}}
{{- printf "%s-config" (include "litellm.fullname" .) }}
{{- end }}

{{/*
Name of the Secret holding the master key.
*/}}
{{- define "litellm.masterKeySecretName" -}}
{{- if .Values.masterKey.existingSecret }}
{{- .Values.masterKey.existingSecret }}
{{- else }}
{{- printf "%s-master-key" (include "litellm.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Name of the Secret holding Redis password.
*/}}
{{- define "litellm.redisSecretName" -}}
{{- if .Values.redis.existingSecret }}
{{- .Values.redis.existingSecret }}
{{- else }}
{{- printf "%s-redis" (include "litellm.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Name of the Secret holding the database URL.
*/}}
{{- define "litellm.databaseSecretName" -}}
{{- if .Values.database.existingSecret }}
{{- .Values.database.existingSecret }}
{{- else }}
{{- printf "%s-database" (include "litellm.fullname" .) }}
{{- end }}
{{- end }}
