{{- define "victoria-metrics.labels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}
