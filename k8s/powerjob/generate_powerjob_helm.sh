#!/bin/bash
# generate_powerjob_helm.sh
# 最终版：支持 imagePullSecrets，集成阿里云 ACR 私有仓库认证

set -e

CHART_DIR="powerjob"
TEMPLATES_DIR="${CHART_DIR}/templates"

mkdir -p "${TEMPLATES_DIR}"

# Chart.yaml
cat > "${CHART_DIR}/Chart.yaml" << 'EOF'
apiVersion: v2
name: powerjob
description: A Helm chart for PowerJob distributed job scheduling platform
type: application
version: 0.1.0
appVersion: "latest"
EOF

# values.yaml（包含全局 imagePullSecrets）
cat > "${CHART_DIR}/values.yaml" << 'EOF'
# Default values for powerjob.
replicaCount: 1

# 全局镜像拉取凭证（例如阿里云 ACR 私有仓库）
imagePullSecrets: []
# 使用示例:
# imagePullSecrets:
#   - name: aliyun.acr.vpc

nameOverride: ""
fullnameOverride: ""

# MySQL 配置
mysql:
  enabled: true
  image:
    repository: crpi-2ht4o3mf8mfcxio7-vpc.cn-shenzhen.personal.cr.aliyuncs.com/dous_librarys/powerjob-mysql
    tag: latest
    pullPolicy: IfNotPresent
  port: 3306
  auth:
    username: root
    password: "No1Bug2Please3!"
  database: powerjob-daily
  persistence:
    enabled: true
    size: 10Gi
    storageClass: ""
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"
  nodeSelector: {}
  tolerations: []
  affinity: {}
  commandArgs:
    - "--lower_case_table_names=1"

# PowerJob Server 配置
server:
  enabled: true
  image:
    repository: crpi-2ht4o3mf8mfcxio7-vpc.cn-shenzhen.personal.cr.aliyuncs.com/dous_librarys/powerjob-server
    tag: latest
    pullPolicy: IfNotPresent
  ports:
    - name: server
      containerPort: 7700
      servicePort: 7700
    - name: http
      containerPort: 10086
      servicePort: 10086
    - name: dump
      containerPort: 10010
      servicePort: 10010
    - name: akka
      containerPort: 10077
      servicePort: 10077
  env:
    JVMOPTIONS: "-Xmx512m"
  persistence:
    enabled: true
    size: 1Gi
    storageClass: ""
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"
  nodeSelector: {}
  tolerations: []
  affinity: {}

# PowerJob Worker Sample 配置
worker:
  enabled: true
  image:
    repository: crpi-2ht4o3mf8mfcxio7-vpc.cn-shenzhen.personal.cr.aliyuncs.com/dous_librarys/powerjob-worker-samples
    tag: latest
    pullPolicy: IfNotPresent
  ports:
    - name: http
      containerPort: 8081
      servicePort: 8081
    - name: worker
      containerPort: 27777
      servicePort: 27777
  persistence:
    enabled: true
    size: 1Gi
    storageClass: ""
  serverAddress: "powerjob-server:7700"   # 会被 service name 覆盖
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"
  nodeSelector: {}
  tolerations: []
  affinity: {}

# 初始化等待镜像
initContainer:
  image: crpi-2ht4o3mf8mfcxio7-vpc.cn-shenzhen.personal.cr.aliyuncs.com/dous_librarys/busybox:latest
  imagePullPolicy: IfNotPresent
EOF

# templates/_helpers.tpl
cat > "${TEMPLATES_DIR}/_helpers.tpl" << 'EOF'
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
EOF

# templates/mysql-secret.yaml
cat > "${TEMPLATES_DIR}/mysql-secret.yaml" << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "powerjob.mysql.fullname" . }}-secret
  labels:
    {{- include "powerjob.labels" . | nindent 4 }}
type: Opaque
data:
  mysql-root-password: {{ .Values.mysql.auth.password | b64enc | quote }}
EOF

# templates/mysql-pvc.yaml
cat > "${TEMPLATES_DIR}/mysql-pvc.yaml" << 'EOF'
{{- if .Values.mysql.persistence.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "powerjob.mysql.fullname" . }}-pvc
  labels:
    {{- include "powerjob.labels" . | nindent 4 }}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.mysql.persistence.size }}
  {{- if .Values.mysql.persistence.storageClass }}
  storageClassName: {{ .Values.mysql.persistence.storageClass }}
  {{- end }}
{{- end }}
EOF

# templates/mysql-service.yaml
cat > "${TEMPLATES_DIR}/mysql-service.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ include "powerjob.mysql.fullname" . }}
  labels:
    {{- include "powerjob.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  ports:
    - port: {{ .Values.mysql.port }}
      targetPort: {{ .Values.mysql.port }}
      protocol: TCP
      name: mysql
  selector:
    app.kubernetes.io/component: mysql
    {{- include "powerjob.selectorLabels" . | nindent 4 }}
EOF

# templates/mysql-deployment.yaml（支持 imagePullSecrets）
cat > "${TEMPLATES_DIR}/mysql-deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "powerjob.mysql.fullname" . }}
  labels:
    app.kubernetes.io/component: mysql
    {{- include "powerjob.labels" . | nindent 4 }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/component: mysql
      {{- include "powerjob.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        app.kubernetes.io/component: mysql
        {{- include "powerjob.labels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: mysql
          image: "{{ .Values.mysql.image.repository }}:{{ .Values.mysql.image.tag }}"
          imagePullPolicy: {{ .Values.mysql.image.pullPolicy }}
          args:
            {{- toYaml .Values.mysql.commandArgs | nindent 12 }}
          env:
            - name: MYSQL_ROOT_HOST
              value: "%"
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ include "powerjob.mysql.fullname" . }}-secret
                  key: mysql-root-password
          ports:
            - containerPort: {{ .Values.mysql.port }}
              name: mysql
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
          resources:
            {{- toYaml .Values.mysql.resources | nindent 12 }}
      volumes:
        - name: data
          {{- if .Values.mysql.persistence.enabled }}
          persistentVolumeClaim:
            claimName: {{ include "powerjob.mysql.fullname" . }}-pvc
          {{- else }}
          emptyDir: {}
          {{- end }}
EOF

# templates/server-pvc.yaml
cat > "${TEMPLATES_DIR}/server-pvc.yaml" << 'EOF'
{{- if .Values.server.persistence.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "powerjob.server.fullname" . }}-pvc
  labels:
    {{- include "powerjob.labels" . | nindent 4 }}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.server.persistence.size }}
  {{- if .Values.server.persistence.storageClass }}
  storageClassName: {{ .Values.server.persistence.storageClass }}
  {{- end }}
{{- end }}
EOF

# templates/server-service.yaml
cat > "${TEMPLATES_DIR}/server-service.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ include "powerjob.server.fullname" . }}
  labels:
    app.kubernetes.io/component: server
    {{- include "powerjob.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  ports:
    {{- range .Values.server.ports }}
    - port: {{ .servicePort }}
      targetPort: {{ .containerPort }}
      protocol: TCP
      name: {{ .name }}
    {{- end }}
  selector:
    app.kubernetes.io/component: server
    {{- include "powerjob.selectorLabels" . | nindent 4 }}
EOF

# templates/server-deployment.yaml（支持 imagePullSecrets）
cat > "${TEMPLATES_DIR}/server-deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "powerjob.server.fullname" . }}
  labels:
    app.kubernetes.io/component: server
    {{- include "powerjob.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/component: server
      {{- include "powerjob.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        app.kubernetes.io/component: server
        {{- include "powerjob.labels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      initContainers:
        - name: wait-for-mysql
          image: {{ .Values.initContainer.image }}
          imagePullPolicy: {{ .Values.initContainer.imagePullPolicy }}
          command:
            - sh
            - -c
            - |
              until nc -z {{ include "powerjob.mysql.fullname" . }} {{ .Values.mysql.port }}; do
                echo "Waiting for MySQL..."
                sleep 2
              done
              echo "MySQL is ready"
      containers:
        - name: server
          image: "{{ .Values.server.image.repository }}:{{ .Values.server.image.tag }}"
          imagePullPolicy: {{ .Values.server.image.pullPolicy }}
          env:
            - name: JVMOPTIONS
              value: {{ .Values.server.env.JVMOPTIONS | quote }}
            - name: PARAMS
              value: "--oms.mongodb.enable=false --spring.datasource.core.jdbc-url=jdbc:mysql://{{ include "powerjob.mysql.fullname" . }}:{{ .Values.mysql.port }}/{{ .Values.mysql.database }}?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai&user={{ .Values.mysql.auth.username }}&password={{ .Values.mysql.auth.password }}"
          ports:
            {{- range .Values.server.ports }}
            - containerPort: {{ .containerPort }}
              name: {{ .name }}
            {{- end }}
          volumeMounts:
            - name: data
              mountPath: /root/powerjob/server/
          resources:
            {{- toYaml .Values.server.resources | nindent 12 }}
      volumes:
        - name: data
          {{- if .Values.server.persistence.enabled }}
          persistentVolumeClaim:
            claimName: {{ include "powerjob.server.fullname" . }}-pvc
          {{- else }}
          emptyDir: {}
          {{- end }}
EOF

# templates/worker-pvc.yaml
cat > "${TEMPLATES_DIR}/worker-pvc.yaml" << 'EOF'
{{- if .Values.worker.persistence.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "powerjob.worker.fullname" . }}-pvc
  labels:
    {{- include "powerjob.labels" . | nindent 4 }}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.worker.persistence.size }}
  {{- if .Values.worker.persistence.storageClass }}
  storageClassName: {{ .Values.worker.persistence.storageClass }}
  {{- end }}
{{- end }}
EOF

# templates/worker-service.yaml
cat > "${TEMPLATES_DIR}/worker-service.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ include "powerjob.worker.fullname" . }}
  labels:
    app.kubernetes.io/component: worker
    {{- include "powerjob.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  ports:
    {{- range .Values.worker.ports }}
    - port: {{ .servicePort }}
      targetPort: {{ .containerPort }}
      protocol: TCP
      name: {{ .name }}
    {{- end }}
  selector:
    app.kubernetes.io/component: worker
    {{- include "powerjob.selectorLabels" . | nindent 4 }}
EOF

# templates/worker-deployment.yaml（支持 imagePullSecrets）
cat > "${TEMPLATES_DIR}/worker-deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "powerjob.worker.fullname" . }}
  labels:
    app.kubernetes.io/component: worker
    {{- include "powerjob.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/component: worker
      {{- include "powerjob.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        app.kubernetes.io/component: worker
        {{- include "powerjob.labels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      initContainers:
        - name: wait-for-server
          image: {{ .Values.initContainer.image }}
          imagePullPolicy: {{ .Values.initContainer.imagePullPolicy }}
          command:
            - sh
            - -c
            - |
              until nc -z {{ include "powerjob.server.fullname" . }} 7700; do
                echo "Waiting for PowerJob Server on port 7700..."
                sleep 2
              done
              echo "Server is ready"
      containers:
        - name: worker
          image: "{{ .Values.worker.image.repository }}:{{ .Values.worker.image.tag }}"
          imagePullPolicy: {{ .Values.worker.image.pullPolicy }}
          command:
            - sh
            - -c
            - |
              java -Xmx512m -jar /powerjob-worker-samples.jar --powerjob.worker.server-address={{ include "powerjob.server.fullname" . }}:7700
          ports:
            {{- range .Values.worker.ports }}
            - containerPort: {{ .containerPort }}
              name: {{ .name }}
            {{- end }}
          volumeMounts:
            - name: data
              mountPath: /root/powerjob/worker
          resources:
            {{- toYaml .Values.worker.resources | nindent 12 }}
      volumes:
        - name: data
          {{- if .Values.worker.persistence.enabled }}
          persistentVolumeClaim:
            claimName: {{ include "powerjob.worker.fullname" . }}-pvc
          {{- else }}
          emptyDir: {}
          {{- end }}
EOF

echo "✅ Helm Chart 已成功生成在 ${CHART_DIR} 目录中"
echo "📦 安装命令示例（使用阿里云 ACR 私有仓库凭证）："
echo "   helm install my-powerjob ./${CHART_DIR} --set imagePullSecrets[0].name=aliyun.acr.vpc"
echo ""
echo "🔧 或直接修改 ${CHART_DIR}/values.yaml 中的 imagePullSecrets 字段"
