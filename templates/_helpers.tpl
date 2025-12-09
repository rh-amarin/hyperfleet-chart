{{/*
Expand the name of the chart.
*/}}
{{- define "hyperfleet.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "hyperfleet.fullname" -}}
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
{{- define "hyperfleet.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "hyperfleet.labels" -}}
helm.sh/chart: {{ include "hyperfleet.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: hyperfleet
{{- end }}

{{/*
Global image registry helper - returns global registry if set, otherwise component registry
Usage: {{ include "hyperfleet.imageRegistry" (dict "global" .Values.global "local" .Values.component.image.registry) }}
*/}}
{{- define "hyperfleet.imageRegistry" -}}
{{- if .global.imageRegistry }}
{{- .global.imageRegistry }}
{{- else }}
{{- .local }}
{{- end }}
{{- end }}

{{/*
Global image tag helper - returns global tag if set, otherwise component tag
Usage: {{ include "hyperfleet.imageTag" (dict "global" .Values.global "local" .Values.component.image.tag) }}
*/}}
{{- define "hyperfleet.imageTag" -}}
{{- if .global.imageTag }}
{{- .global.imageTag }}
{{- else }}
{{- .local }}
{{- end }}
{{- end }}
