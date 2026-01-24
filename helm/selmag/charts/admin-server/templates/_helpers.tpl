{{- define "admin-server.labels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}
