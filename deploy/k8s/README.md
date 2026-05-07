

## 1.安装私有仓库

```shell

cat > "./aliyun.acr.vpc.secret.yaml" << 'EOF'
apiVersion: v1
data:
  .dockerconfigjson: >-
    eyJhdXRocyI6eyJodHRwczovL2NycGktMmh0NG8zbWY4bWZjeGlvNy12cGMuY24tc2hlbnpoZW4ucGVyc29uYWwuY3IuYWxpeXVuY3MuY29tIjp7InVzZXJuYW1lIjoiZG91c29uZ2thZmthIiwicGFzc3dvcmQiOiJmZWZuWWotd29id3luLTFnaW1qaSIsImF1dGgiOiJaRzkxYzI5dVoydGhabXRoT21abFptNVphaTEzYjJKM2VXNHRNV2RwYldwcCJ9fX0=
immutable: false
kind: Secret
metadata:
  name: aliyun.acr.vpc
type: kubernetes.io/dockerconfigjson

EOF

# 使用您提供的 Secret 文件
kubectl apply -f aliyun.acr.vpc.secret.yaml

```

## 2.[安装 Provisioner](Provisioner/README.md)

## 3.[安装 powerjob](powerjob/README.md)
