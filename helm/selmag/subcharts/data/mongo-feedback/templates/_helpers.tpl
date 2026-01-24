{{- define "mongo-feedback.labels" -}}
app: {{ .Values.statefulset.appLabel }}
{{- end -}}

{{- define "mongo-feedback.selectorLabels" -}}
app: {{ .Values.statefulset.appLabel }}
{{- end -}}
