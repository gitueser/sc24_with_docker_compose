{{- define "selmag.configMapName" -}}
{{- default "selmag-config" .Values.global.configMapName -}}
{{- end -}}

{{- define "selmag.secretName" -}}
{{- default "selmag-secret" .Values.global.secretName -}}
{{- end -}}
