{{/*
Istio Ambient Mesh helpers.

arieotech.istioAmbientLabels — emits the pod label that opts the pod into the
Ambient mesh when .Values.istio.ambient.enabled is true.

arieotech.istioExcludedPorts — emits the ztunnel traffic-exclusion annotation
when .Values.istio.ambient.enabled is true and excludedPorts is non-empty.
*/}}

{{- define "arieotech.istioAmbientLabels" -}}
{{- if and .Values.istio .Values.istio.ambient .Values.istio.ambient.enabled }}
istio.io/dataplane-mode: ambient
{{- end }}
{{- end }}

{{- define "arieotech.istioExcludedPorts" -}}
{{- if and .Values.istio .Values.istio.ambient .Values.istio.ambient.enabled .Values.istio.ambient.excludedPorts }}
traffic.sidecar.istio.io/excludeInboundPorts: {{ .Values.istio.ambient.excludedPorts | join "," | quote }}
{{- end }}
{{- end }}
