{{/*
PSA restricted-compatible pod security context.
Sets runAsNonRoot, seccompProfile, and optional fsGroup.
*/}}
{{- define "arieotech.podSecurityContext" -}}
{{- with .Values.podSecurityContext }}
{{- toYaml . }}
{{- else }}
runAsNonRoot: true
runAsUser: 1000
runAsGroup: 1000
fsGroup: 1000
seccompProfile:
  type: RuntimeDefault
{{- end }}
{{- end }}

{{/*
PSA restricted-compatible container security context.
Drops ALL capabilities, disables privilege escalation, enforces read-only root filesystem.
Override per-container only when the upstream image explicitly requires a write path.
*/}}
{{- define "arieotech.containerSecurityContext" -}}
{{- with .Values.securityContext }}
{{- toYaml . }}
{{- else }}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
runAsUser: 1000
capabilities:
  drop:
    - ALL
seccompProfile:
  type: RuntimeDefault
{{- end }}
{{- end }}
