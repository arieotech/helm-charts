{{/*
Render the full image reference.
Digest takes precedence over tag when set — use digest in production for immutability.
Usage: image: {{ include "arieotech.image" .Values.image | quote }}
*/}}
{{- define "arieotech.image" -}}
{{- $img := . -}}
{{- if $img.digest -}}
{{ $img.registry }}/{{ $img.repository }}@{{ $img.digest }}
{{- else -}}
{{ $img.registry }}/{{ $img.repository }}:{{ $img.tag }}
{{- end -}}
{{- end }}
