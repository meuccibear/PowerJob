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
