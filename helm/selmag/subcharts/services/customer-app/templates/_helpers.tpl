{{- define "customer-app.labels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}
