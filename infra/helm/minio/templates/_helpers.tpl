{{- define "minio.name" -}}
minio
{{- end }}

{{- define "minio.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "minio.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "minio.labels" -}}
app.kubernetes.io/name: {{ include "minio.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: ytr
{{- end }}

{{- define "minio.selectorLabels" -}}
app.kubernetes.io/name: {{ include "minio.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

