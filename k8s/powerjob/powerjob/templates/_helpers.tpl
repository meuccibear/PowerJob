{{- define "powerjob.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "powerjob.fullname" -}}
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
{{- define "powerjob.labels" -}}
helm.sh/chart: {{ include "powerjob.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "powerjob.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "powerjob.selectorLabels" -}}
app.kubernetes.io/name: {{ include "powerjob.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "powerjob.mysql.fullname" -}}
{{- printf "%s-mysql" (include "powerjob.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "powerjob.server.fullname" -}}
{{- printf "%s-server" (include "powerjob.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "powerjob.worker.fullname" -}}
{{- printf "%s-worker" (include "powerjob.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
