{{- define "catalogue-service.labels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}
