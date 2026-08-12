{{/*
Standard labels for every CRD in this chart.
*/}}
{{- define "karpenter-crds.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: karpenter
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Standard annotations for every CRD in this chart. helm.sh/resource-policy: keep
prevents `helm uninstall` from deleting the CRD (and the live NodePool/NodeClaim/
EC2NodeClass resources it backs) — this is the entire point of splitting CRDs into
their own chart, and the Arieotech fix for ArgoCD CRD drift (upstream #6847).
Set keepCRDs: false to opt out (e.g. ephemeral CI clusters).
*/}}
{{- define "karpenter-crds.annotations" -}}
{{- if .Values.keepCRDs }}
helm.sh/resource-policy: keep
{{- end }}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}
