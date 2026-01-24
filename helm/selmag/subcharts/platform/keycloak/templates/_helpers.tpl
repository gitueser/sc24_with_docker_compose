{{- define "keycloak.labels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}

{{- define "keycloak.selectorLabels" -}}
app: {{ .Values.deployment.appLabel }}
{{- end -}}
