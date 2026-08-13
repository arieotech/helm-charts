{{- define "karpenter.name" -}}
{{- include "arieotech.name" . }}
{{- end }}

{{- define "karpenter.fullname" -}}
{{- include "arieotech.fullname" . }}
{{- end }}

{{- define "karpenter.chart" -}}
{{- include "arieotech.chart" . }}
{{- end }}

{{- define "karpenter.labels" -}}
{{- include "arieotech.labels" . }}
{{- end }}

{{- define "karpenter.selectorLabels" -}}
{{- include "arieotech.selectorLabels" . }}
{{- end }}

{{- define "karpenter.serviceAccountName" -}}
{{- include "arieotech.serviceAccountName" . }}
{{- end }}

{{/*
FEATURE_GATES value — Karpenter reads a single comma-separated env var in Go
feature-gate format (Name=bool). Keys in .Values.settings.featureGates are used
verbatim, so they must be the exact PascalCase gate names Karpenter recognises
(ReservedCapacity, SpotToSpotConsolidation, NodeRepair, NodeOverlay, StaticCapacity,
CapacityBuffer). range over a map iterates in sorted-key order, so the rendered
string is deterministic across template runs (no spurious rollout diffs).
Note: `drift` is NOT a feature gate in Karpenter v1 — drift detection is GA and
always on; there is no toggle for it here.
*/}}
{{- define "karpenter.featureGates" -}}
{{- $parts := list -}}
{{- range $k, $v := .Values.settings.featureGates }}
{{- $parts = append $parts (printf "%s=%v" $k $v) }}
{{- end }}
{{- join "," $parts }}
{{- end }}

{{/*
Pod annotations block (Istio ambient ztunnel exclusion + DPDP data-residency +
user-supplied podAnnotations), emitted only when at least one is actually present so
an empty `annotations:` key never renders as YAML null. Usage:
{{ include "karpenter.podAnnotations" . | nindent 6 }} in the pod template's metadata.
*/}}
{{- define "karpenter.podAnnotations" -}}
{{- $parts := list -}}
{{- with (include "arieotech.istioExcludedPorts" . | trim) }}
{{- $parts = append $parts . }}
{{- end }}
{{- if and .Values.dpdp.dataResidency.enabled .Values.dpdp.dataResidency.region }}
{{- $parts = append $parts (printf "dpdp.arieotech.com/data-residency-region: %s" (.Values.dpdp.dataResidency.region | quote)) }}
{{- end }}
{{- with .Values.podAnnotations }}
{{- $parts = append $parts (trim (toYaml .)) }}
{{- end }}
{{- if $parts }}
annotations:
{{- range $parts }}
{{ indent 2 . }}
{{- end }}
{{- end }}
{{- end }}
