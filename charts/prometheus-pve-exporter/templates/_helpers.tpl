{{/*
Expand the name of the chart.
*/}}
{{- define "prometheus-pve-exporter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "prometheus-pve-exporter.fullname" -}}
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
{{- define "prometheus-pve-exporter.chart" -}}
  {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "prometheus-pve-exporter.labels" -}}
helm.sh/chart: {{ include "prometheus-pve-exporter.chart" . }}
{{ include "prometheus-pve-exporter.selectorLabels" . }}
  {{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
  {{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "prometheus-pve-exporter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "prometheus-pve-exporter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "prometheus-pve-exporter.serviceAccountName" -}}
  {{- if .Values.serviceAccount.create }}
{{- default (include "prometheus-pve-exporter.fullname" .) .Values.serviceAccount.name }}
  {{- else }}
{{- default "default" .Values.serviceAccount.name }}
  {{- end }}
{{- end }}

{{/*
Name of the Secret holding the Proxmox credentials.
*/}}
{{- define "prometheus-pve-exporter.secretName" -}}
{{- default (include "prometheus-pve-exporter.fullname" .) .Values.pve.existingSecret }}
{{- end }}

{{/*
Renders "true" when token authentication is selected: pve.tokenName is set, or a token key name is configured for an existing Secret.
*/}}
{{- define "prometheus-pve-exporter.tokenAuth" -}}
  {{- if or .Values.pve.tokenName .Values.pve.tokenNameKey .Values.pve.tokenValueKey }}true{{- end }}
{{- end }}

{{/*
Fail the render on invalid credential configuration.
*/}}
{{- define "prometheus-pve-exporter.validate" -}}
  {{- $token := include "prometheus-pve-exporter.tokenAuth" . }}
  {{- if and $token .Values.pve.password }}
    {{- fail "pve.password cannot be combined with token authentication (pve.tokenName, pve.tokenNameKey or pve.tokenValueKey); set only one" }}
  {{- end }}
  {{- if not .Values.pve.existingSecret }}
    {{- if not .Values.pve.user }}
      {{- fail "pve.user is required unless pve.existingSecret is set" }}
    {{- end }}
    {{- if and $token (not .Values.pve.tokenName) }}
      {{- fail "pve.tokenName is required for token authentication" }}
    {{- end }}
    {{- if and $token (not .Values.pve.tokenValue) }}
      {{- fail "pve.tokenValue is required for token authentication" }}
    {{- end }}
    {{- if and (not $token) (not .Values.pve.password) }}
      {{- fail "pve.password (or pve.tokenName and pve.tokenValue) is required unless pve.existingSecret is set" }}
    {{- end }}
  {{- end }}
{{- end }}
