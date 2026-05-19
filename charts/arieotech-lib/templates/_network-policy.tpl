{{/*
Render a NetworkPolicy with deny-all default + caller-provided allow-list.
Usage in a chart's networkpolicy.yaml:
  {{- include "arieotech.networkPolicy" (dict "root" . "ingress" $ingressRules "egress" $egressRules) }}

The caller is responsible for defining $ingressRules and $egressRules as YAML slices.
*/}}
{{- define "arieotech.networkPolicy" -}}
{{- $root := .root }}
{{- if $root.Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "arieotech.fullname" $root }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "arieotech.labels" $root | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "arieotech.selectorLabels" $root | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    {{- if .ingress }}
    {{- toYaml .ingress | nindent 4 }}
    {{- else }}
    []
    {{- end }}
  egress:
    {{- if .egress }}
    {{- toYaml .egress | nindent 4 }}
    {{- else }}
    # Always allow DNS
    - ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
    {{- end }}
{{- end }}
{{- end }}
