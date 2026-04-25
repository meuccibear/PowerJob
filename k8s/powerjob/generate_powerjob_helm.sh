#!/bin/bash
set -e
CHART_DIR="powerjob"
TEMPLATES_DIR="${CHART_DIR}/templates"
mkdir -p "${TEMPLATES_DIR}"

# Chart.yaml
cat > "${CHART_DIR}/Chart.yaml" << 'EOF'
apiVersion: v2
name: powerjob
description: PowerJob distributed job scheduling platform
type: application
version: 0.2.0
appVersion: "5.1.2"
EOF

# values.yaml
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
    storageClass: ""   # 空字符串表示使用静态 PV 或默认 StorageClass
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"
  commandArgs:
    - "--lower_case_table_names=1"

# PowerJob Server 配置
server:
  enabled: true
  image:
    repository: crpi-2ht4o3mf8mfcxio7-vpc.cn-shenzhen.personal.cr.aliyuncs.com/dous_librarys/powerjob-server
    tag: latest
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 10086     # 内部通信端口
    httpPort: 7700  # Web 控制台端口
  ports:
    - name: server
      containerPort: 10086
      servicePort: 10086
    - name: http
      containerPort: 7700
      servicePort: 7700
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

# PowerJob Worker Sample 配置
worker:
  enabled: true
  image:
    repository: crpi-2ht4o3mf8mfcxio7-vpc.cn-shenzhen.personal.cr.aliyuncs.com/dous_librarys/powerjob-worker-samples
    tag: latest
    pullPolicy: IfNotPresent
  service:
    enabled: false   # Worker 通常不需要暴露 Service
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
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"

# Ingress 配置 (用于暴露 Server Web 控制台)
ingress:
  enabled: false
  className: "nginx"
  annotations: {}
    # kubernetes.io/ingress.class: nginx
    # cert-manager.io/cluster-issuer: "letsencrypt"
  hosts:
    - host: powerjob.example.com
      paths:
        - path: /
          pathType: Prefix
  tls: []
  #  - secretName: powerjob-tls
  #    hosts:
  #      - powerjob.example.com

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

# templates/mysql-deployment.yaml
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
  type: {{ .Values.server.service.type }}
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

# templates/server-deployment.yaml
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
{{- if .Values.worker.service.enabled }}
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
{{- end }}
EOF

# templates/worker-deployment.yaml (包含端口环境变量修复)
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
          env:
            - name: POWERJOB_WORKER_PORT
              value: "27777"
          command:
            - sh
            - -c
            - |
              java -Xmx512m -jar /powerjob-worker-samples.jar \
                --powerjob.worker.server-address={{ include "powerjob.server.fullname" . }}:7700 \
                --powerjob.worker.port=27777
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

# templates/ingress.yaml (新增)
cat > "${TEMPLATES_DIR}/ingress.yaml" << 'EOF'
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "powerjob.fullname" . }}-web
  labels:
    {{- include "powerjob.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- toYaml .Values.ingress.tls | nindent 4 }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "powerjob.server.fullname" $ }}
                port:
                  number: {{ $.Values.server.service.httpPort }}
          {{- end }}
    {{- end }}
{{- end }}
EOF

echo "✅ 最终版 Helm Chart 已生成在 ${CHART_DIR} 目录"
echo "📌 请先手动创建所需的静态 PV (如果需要)，或确保有默认 StorageClass"
echo "🚀 部署命令:"
echo "   helm upgrade --install powerjob ./${CHART_DIR} -n powerjob --create-namespace \\"
echo "     --set imagePullSecrets[0].name=aliyun.acr.vpc \\"
echo "     --set ingress.enabled=true \\"
echo "     --set ingress.hosts[0].host=powerjob.your-domain.com"
cat > "${CHART_DIR}/README.md" << 'EOF'
## 🚀 使用方法

### 1. 生成 Helm Chart

```bash
chmod +x generate_powerjob_helm_final.sh
./generate_powerjob_helm_final.sh
```

### 2. （可选）创建静态 PV（如果集群无动态 StorageClass）

参考之前的静态 PV 配置，确保 `/data/powerjob/mysql`、`/data/powerjob/server`、`/data/powerjob/worker` 目录存在并有权限。

### 3. 部署 PowerJob（启用 Ingress）

```bash
helm upgrade --install powerjob ./powerjob -n powerjob --create-namespace \
  --set imagePullSecrets[0].name=aliyun.acr.vpc \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=powerjob.example.com   # 替换为你的域名
```

如果暂时不需要 Ingress，可以省略 `--set ingress.enabled=true` 等参数，默认 Ingress 是关闭的。

### 4. 验证部署

```bash
# 查看所有资源
kubectl get all -n powerjob

# 查看 Ingress
kubectl get ingress -n powerjob

# 查看 Worker 日志（确认端口错误已修复）
kubectl logs -f deployment/powerjob-worker -n powerjob
```

---

## 📌 最终版改进点

1. **Worker 端口修复**：在 Deployment 模板中显式设置环境变量 `POWERJOB_WORKER_PORT=27777`，并在 command 中通过 `--powerjob.worker.port=27777` 双重保险。
2. **Ingress 支持**：新增 `ingress.yaml` 模板，可通过 values 灵活配置域名、TLS、注解等。
3. **Service 类型可配置**：Server Service 的 `type` 默认为 `ClusterIP`，可改为 `NodePort` 或 `LoadBalancer`。
4. **全局 imagePullSecrets**：已集成至所有 Deployment。
5. **静态 PV 兼容**：`storageClass: ""` 默认空字符串，便于绑定手动创建的 PV。

---

## 🔧 后续管理

- **升级**：修改 `values.yaml` 或使用 `--set` 后，再次执行 `helm upgrade` 即可。
- **卸载**：`helm uninstall powerjob -n powerjob`
- **访问控制台**：配置好 Ingress 后，通过域名访问。如果没有 Ingress Controller，也可以临时使用 `kubectl port-forward svc/powerjob-server 10086:10086 -n powerjob` 并访问 `http://localhost:10086`。

现在您可以直接使用这个最终版方案，一次性解决所有问题。
EOF
