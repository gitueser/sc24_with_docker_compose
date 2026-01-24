{{- define "api-gateway.labels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}
