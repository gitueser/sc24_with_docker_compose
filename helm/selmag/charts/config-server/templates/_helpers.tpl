{{- define "config-server.labels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}

{{- define "config-server.selectorLabels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}
