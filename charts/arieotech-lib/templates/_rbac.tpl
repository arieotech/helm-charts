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

{{/*
Projected ServiceAccount token volume — for pods that disable automountServiceAccountToken
at the pod/ServiceAccount level for hardening but still need to authenticate to the
Kubernetes API (e.g. operators, aggregated API servers, admission webhooks). Mirrors the
volume Kubernetes would auto-inject, with an explicit short-lived, audience-scoped token.
Usage: {{ include "arieotech.serviceAccountTokenVolume" . | nindent N }} inside `volumes:`.
*/}}
{{- define "arieotech.serviceAccountTokenVolume" -}}
- name: kube-api-access
  projected:
    defaultMode: 420
    sources:
      - serviceAccountToken:
          expirationSeconds: 3607
          path: token
      - configMap:
          name: kube-root-ca.crt
          items:
            - key: ca.crt
              path: ca.crt
      - downwardAPI:
          items:
            - path: namespace
              fieldRef:
                fieldPath: metadata.namespace
{{- end }}

{{/*
Matching volumeMount for arieotech.serviceAccountTokenVolume.
Usage: {{ include "arieotech.serviceAccountTokenVolumeMount" . | nindent N }} inside `volumeMounts:`.
*/}}
{{- define "arieotech.serviceAccountTokenVolumeMount" -}}
- name: kube-api-access
  mountPath: /var/run/secrets/kubernetes.io/serviceaccount
  readOnly: true
{{- end }}
