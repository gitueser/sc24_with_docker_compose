{{- define "keycloak.fullname" -}}
{{- printf "%s-%s" .Release.Name "keycloak" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "keycloak.realmSecretName" -}}
{{- printf "%s-realm" (include "keycloak.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
