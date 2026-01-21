{{- define "config-server.labels" -}}
app: {{ .Values.deployment.name }}
{{- end -}}
