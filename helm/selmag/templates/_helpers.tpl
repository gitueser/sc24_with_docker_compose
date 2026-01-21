{{- define "selmag.namespace" -}}
{{- default .Release.Namespace .Values.global.namespace -}}
{{- end -}}

{{- define "selmag.configMapName" -}}
{{- default "selmag-config" .Values.global.configMapName -}}
{{- end -}}

{{- define "selmag.secretName" -}}
{{- default "selmag-secret" .Values.global.secretName -}}
{{- end -}}
