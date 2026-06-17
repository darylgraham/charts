{{/*
Expand the name of the chart.
*/}}
{{- define "home-information.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "home-information.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "home-information.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "home-information.labels" -}}
helm.sh/chart: {{ include "home-information.chart" . }}
{{ include "home-information.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "home-information.selectorLabels" -}}
app.kubernetes.io/name: {{ include "home-information.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Resolve the name of the configuration configmap.
*/}}
{{- define "home-information.configMapName" -}}
{{- if .Values.config.existingConfigMap }}
{{- .Values.config.existingConfigMap }}
{{- else }}
{{- printf "%s-config" (include "home-information.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Resolve the secretKeyRef for DJANGO_SECRET_KEY.
Uses config.existingSecretName/existingSecretKey when provided, otherwise falls back to the generated secret.
*/}}
{{- define "home-information.djangoSecretKeyRef" -}}
{{- if .Values.config.existingSecretName }}
name: {{ .Values.config.existingSecretName }}
key: {{ .Values.config.existingSecretKey }}
{{- else }}
name: {{ include "home-information.secretName" . }}
key: SECRET_KEY
{{- end }}
{{- end }}

{{/*
Resolve the name of the chart-managed secret.
*/}}
{{- define "home-information.secretName" -}}
{{- if .Values.config.auth.secretName }}
{{- .Values.config.auth.secretName }}
{{- else }}
{{- printf "%s-secret" (include "home-information.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Resolve the secret name for superuser credentials.
Returns config.auth.existingSecret when provided, otherwise the chart-managed secret.
*/}}
{{- define "home-information.authSecretName" -}}
{{- if .Values.config.auth.existingSecret }}
{{- .Values.config.auth.existingSecret }}
{{- else }}
{{- include "home-information.secretName" . }}
{{- end }}
{{- end }}

{{/*
Resolve the key for DJANGO_SUPERUSER_PASSWORD inside the auth secret.
*/}}
{{- define "home-information.secretKey" -}}
{{- if .Values.config.auth.existingSecret }}
{{- default "SUPERUSER_PASSWORD" .Values.config.auth.existingSecretKey }}
{{- else }}
{{- "SUPERUSER_PASSWORD" }}
{{- end }}
{{- end }}

{{/*
Resolve the PVC name for the database volume.
*/}}
{{- define "home-information.databasePvcName" -}}
{{- if .Values.persistence.database.existingClaim }}
{{- .Values.persistence.database.existingClaim }}
{{- else }}
{{- printf "%s-database" (include "home-information.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Resolve the PVC name for the media volume.
*/}}
{{- define "home-information.mediaPvcName" -}}
{{- if .Values.persistence.media.existingClaim }}
{{- .Values.persistence.media.existingClaim }}
{{- else }}
{{- printf "%s-media" (include "home-information.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Generate a space-separated list of URLs from ingress.hosts.
Uses https when ingress.tls is configured, http otherwise.
*/}}
{{- define "home-information.ingressURLs" -}}
{{- $scheme := ternary "https" "http" (gt (len .Values.ingress.tls) 0) -}}
{{- $urls := list -}}
{{- range .Values.ingress.hosts -}}
  {{- $urls = append $urls (printf "%s://%s" $scheme .host) -}}
{{- end -}}
{{- join " " $urls -}}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "home-information.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "home-information.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
