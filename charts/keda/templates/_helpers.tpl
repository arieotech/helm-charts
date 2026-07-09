{{- define "keda.name" -}}
{{- include "arieotech.name" . }}
{{- end }}

{{- define "keda.fullname" -}}
{{- include "arieotech.fullname" . }}
{{- end }}

{{- define "keda.chart" -}}
{{- include "arieotech.chart" . }}
{{- end }}

{{- define "keda.labels" -}}
{{- include "arieotech.labels" . }}
{{- end }}

{{- define "keda.selectorLabels" -}}
{{- include "arieotech.selectorLabels" . }}
{{- end }}

{{/*
Per-component ServiceAccount names. Each component gets its own ServiceAccount so its
ClusterRole/Role bindings don't leak into the other two components — a single shared
ServiceAccount bound to all three ClusterRoles would give every pod the union of all
three components' permissions, defeating least-privilege separation between them.
If serviceAccount.name is explicitly set, all three components share that one name
(an intentional opt-out of the per-component split, not the default behavior).
*/}}
{{- define "keda.operatorServiceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (printf "%s-operator" (include "keda.fullname" .)) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "keda.metricsServiceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (printf "%s-metrics-apiserver" (include "keda.fullname" .)) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "keda.webhooksServiceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (printf "%s-admission-webhooks" (include "keda.fullname" .)) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Operator component selector labels — used by the operator Deployment and Service.
*/}}
{{- define "keda.operatorSelectorLabels" -}}
{{ include "keda.selectorLabels" . }}
app.kubernetes.io/component: operator
{{- end }}

{{/*
Pod annotations block (Istio ambient ztunnel exclusion + DPDP data-residency +
user-supplied podAnnotations), emitted only when at least one is actually present.
With none set (the default), an unconditional `annotations:` key would render as
YAML null, which Kubernetes expects to be a map. Usage:
{{ include "keda.podAnnotations" . | nindent 6 }} in a pod template's `metadata:`.
*/}}
{{- define "keda.podAnnotations" -}}
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

{{/*
Metrics API Server component selector labels.
*/}}
{{- define "keda.metricsSelectorLabels" -}}
{{ include "keda.selectorLabels" . }}
app.kubernetes.io/component: metrics-apiserver
{{- end }}

{{/*
Admission Webhooks component selector labels.
*/}}
{{- define "keda.webhooksSelectorLabels" -}}
{{ include "keda.selectorLabels" . }}
app.kubernetes.io/component: admission-webhooks
{{- end }}

{{/*
Render an image reference for a component-specific image block.
Accepts a dict with keys: registry, repository, tag, digest.
*/}}
{{- define "keda.componentImage" -}}
{{- $img := . -}}
{{- if $img.digest -}}
{{ $img.registry }}/{{ $img.repository }}@{{ $img.digest }}
{{- else -}}
{{ $img.registry }}/{{ $img.repository }}:{{ $img.tag }}
{{- end -}}
{{- end }}

{{/*
NetworkPolicy egress rule for the Kubernetes API server. Restricted to
networkPolicy.kubeApiServerCIDR when set; otherwise port-only (Kubernetes
NetworkPolicy has no generic pod/namespace selector for the API server, since it
typically runs outside the pod network) — see the comment in values.yaml.
*/}}
{{- define "keda.kubeApiServerEgressRule" -}}
{{- if .Values.networkPolicy.kubeApiServerCIDR }}
- to:
    - ipBlock:
        cidr: {{ .Values.networkPolicy.kubeApiServerCIDR }}
  ports:
    - port: 6443
      protocol: TCP
    - port: 443
      protocol: TCP
{{- else }}
## Port-only: allows HTTPS egress to ANY destination on 443/6443, not just the API
## server. Set networkPolicy.kubeApiServerCIDR to restrict this.
- ports:
    - port: 6443
      protocol: TCP
    - port: 443
      protocol: TCP
{{- end }}
{{- end }}

{{/*
NetworkPolicy ingress rule for traffic FROM the Kubernetes API server (e.g.
kube-aggregator proxying to the Metrics API Server, or kube-apiserver calling an
admission webhook). Restricted to networkPolicy.kubeApiServerCIDR when set (the same
value used for the egress rule above, since both describe the API server's address);
otherwise port-only. Accepts a dict: {root: $, port: <port number>}.
*/}}
{{- define "keda.kubeApiServerIngressRule" -}}
{{- if .root.Values.networkPolicy.kubeApiServerCIDR }}
- from:
    - ipBlock:
        cidr: {{ .root.Values.networkPolicy.kubeApiServerCIDR }}
  ports:
    - port: {{ .port }}
      protocol: TCP
{{- else }}
## Port-only: allows inbound traffic from ANY source on this port, not just the API
## server. Set networkPolicy.kubeApiServerCIDR to restrict this.
- ports:
    - port: {{ .port }}
      protocol: TCP
{{- end }}
{{- end }}
