{{/*
Expand the name of the chart.
*/}}
{{- define "hyperfleet-base.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "hyperfleet-base.fullname" -}}
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
{{- define "hyperfleet-base.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "hyperfleet-base.labels" -}}
helm.sh/chart: {{ include "hyperfleet-base.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: hyperfleet
{{- end }}

{{/*
Global image registry helper - returns global registry if set, otherwise component registry
Usage: {{ include "hyperfleet-base.imageRegistry" (dict "global" .Values.global "local" .Values.component.image.registry) }}
*/}}
{{- define "hyperfleet-base.imageRegistry" -}}
{{- if and .global .global.image .global.image.registry }}
{{- .global.image.registry }}
{{- else }}
{{- .local }}
{{- end }}
{{- end }}

{{/*
Global image tag helper - returns global tag if set, otherwise component tag
Usage: {{ include "hyperfleet-base.imageTag" (dict "global" .Values.global "local" .Values.component.image.tag) }}
*/}}
{{- define "hyperfleet-base.imageTag" -}}
{{- if and .global .global.image .global.image.tag }}
{{- .global.image.tag }}
{{- else }}
{{- .local }}
{{- end }}
{{- end }}

{{/*
RabbitMQ URL helper - generates URL from in-cluster RabbitMQ or uses provided URL
*/}}
{{- define "hyperfleet-base.rabbitmqUrl" -}}
{{- if .Values.global.broker.rabbitmq.url }}
{{- .Values.global.broker.rabbitmq.url }}
{{- else if .Values.rabbitmq.enabled }}
{{- printf "amqp://%s:%s@%s-rabbitmq:5672/" .Values.rabbitmq.auth.username .Values.rabbitmq.auth.password .Release.Name }}
{{- else }}
{{- "" }}
{{- end }}
{{- end }}
