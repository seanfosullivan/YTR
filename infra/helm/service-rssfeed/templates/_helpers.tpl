{{- define "service-rssfeed.labels" -}}
app.kubernetes.io/name: service-rssfeed
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: ytr
{{- end }}
