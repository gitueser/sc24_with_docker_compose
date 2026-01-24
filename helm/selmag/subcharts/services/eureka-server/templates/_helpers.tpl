{{- define "eureka-server.labels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}

{{- define "eureka-server.selectorLabels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}
