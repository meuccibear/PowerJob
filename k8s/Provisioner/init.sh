#!/bin/bash

kubectl create namespace powerjob

kubectl get secret aliyun.acr.vpc --namespace=default -o yaml | \
  sed 's/namespace: default/namespace: local-path-storage/' | \
  kubectl apply --namespace=local-path-storage -f -


kubectl apply -f local-path-storage.yaml
