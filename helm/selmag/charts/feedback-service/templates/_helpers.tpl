{{- define "feedback-service.labels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}
