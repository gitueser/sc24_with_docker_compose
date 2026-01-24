{{- define "manager-app.labels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}
