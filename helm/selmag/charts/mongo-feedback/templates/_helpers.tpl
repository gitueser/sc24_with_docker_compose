{{- define "mongo-feedback.fullname" -}}
{{- .Values.statefulset.name -}}
{{- end -}}

{{- define "mongo-feedback.labels" -}}
app: {{ .Values.statefulset.name }}
{{- end -}}
