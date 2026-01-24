{{- define "postgres-catalogue.labels" -}}
app: {{ .Values.statefulset.appLabel }}
{{- end -}}

{{- define "postgres-catalogue.selectorLabels" -}}
app: {{ .Values.statefulset.appLabel }}
{{- end -}}
