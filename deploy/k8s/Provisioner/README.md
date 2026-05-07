## 1.安装 Provisioner

```shell

# 1.创建命名空间
kubectl create namespace powerjob

# 2.将密钥copy到当前 命名空间
kubectl get secret aliyun.acr.vpc --namespace=default -o yaml | \
  sed 's/namespace: default/namespace: local-path-storage/' | \
  kubectl apply --namespace=local-path-storage -f -

# 3.安装
kubectl apply -f local-path-storage.yaml

```
