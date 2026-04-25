#!/bin/bash

kubectl create namespace powerjob

kubectl get secret aliyun.acr.vpc --namespace=default -o yaml | \
  sed 's/namespace: default/namespace: powerjob/' | \
  kubectl apply --namespace=powerjob -f -

helm install powerjob ./powerjob   --namespace powerjob   --create-namespace   --set imagePullSecrets[0].name=aliyun.acr.vpc

helm upgrade --install powerjob ./powerjob -n powerjob --create-namespace   --set imagePullSecrets[0].name=aliyun.acr.vpc

# 删除 powerjob 命名空间下的所有 PVC（如果存在）
kubectl delete pvc --all -n powerjob

# 删除手动创建的 PV（如果之前创建了静态 PV）
kubectl delete pv powerjob-mysql-pv powerjob-server-pv powerjob-worker-pv --ignore-not-found=true

# 可选：如果存在 local-path-storage 命名空间中的 helper pod 残留，可以一并删除（不影响下次部署）
kubectl delete pods -n local-path-storage --all --ignore-not-found=true

helm uninstall powerjob -n powerjob


