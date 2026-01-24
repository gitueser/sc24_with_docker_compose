{{- define "grafana.labels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}
