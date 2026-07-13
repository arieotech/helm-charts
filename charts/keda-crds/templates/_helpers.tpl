{{/*
Standard labels for every CRD in this chart.
*/}}
{{- define "keda-crds.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: keda-operator
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Standard annotations for every CRD in this chart. helm.sh/resource-policy: keep
prevents `helm uninstall` from deleting the CRD (and the live custom resources
it backs) — this is the entire point of splitting CRDs into their own chart.
*/}}
{{- define "keda-crds.annotations" -}}
helm.sh/resource-policy: keep
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}
