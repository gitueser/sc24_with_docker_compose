{{- define "loki.labels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}
