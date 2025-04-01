---
title: "Filebrowser 部署"
date: 2025-03-30T20:35:54+08:00
# bookComments: false
# bookSearchExclude: false
---

在 k8s 中部署 [filebrowser](https://github.com/filebrowser/filebrowser)

装完后默认密码 `admin` / `admin`, [File Browser Install](https://filebrowser.org/installation)

配置文件样例: [settings.json](https://github.com/filebrowser/filebrowser/blob/master/docker/root/defaults/settings.json)

关于数据持久化，都是持久化在 `ceph` 块存储中，使用 `sc/ceph-block`

- 数据库存储在 `pvc/filebrowser-database-pvc` 中，分配 `1Gi`
- 文件目录存储在 `pvc/filebrowser-data-pvc` 中，分配 `50Gi`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: filebrowser
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebrowser-config
  namespace: filebrowser
data:
  settings.json: |
    {
      "port": 80,
      "baseURL": "",
      "address": "",
      "log": "stdout",
      "database": "/database/filebrowser.db",
      "root": "/srv"
    }
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: filebrowser-database-pvc
  namespace: filebrowser
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ceph-block
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: filebrowser-data-pvc
  namespace: filebrowser
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ceph-block
  resources:
    requests:
      storage: 50Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filebrowser
  namespace: filebrowser
  labels:
    app: filebrowser
spec:
  replicas: 1
  selector:
    matchLabels:
      app: filebrowser
  template:
    metadata:
      labels:
        app: filebrowser
    spec:
      containers:
      - env:
        - name: PUID
          value: "0"
        - name: PGID
          value: "0"
        name: filebrowser
        image: filebrowser/filebrowser:s6
        ports:
        - containerPort: 80
        volumeMounts:
        - name: filebrowser-config
          mountPath: /config
        - name: filebrowser-database
          mountPath: /database
        - name: filebrowser-data
          mountPath: /srv
      volumes:
      - name: filebrowser-config
        configMap:
          name: filebrowser-config
      - name: filebrowser-database
        persistentVolumeClaim:
          claimName: filebrowser-database-pvc
      - name: filebrowser-data
        persistentVolumeClaim:
          claimName: filebrowser-data-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: filebrowser
  namespace: filebrowser
spec:
  selector:
    app: filebrowser
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: filebrowser-ingress
  namespace: filebrowser
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"  
spec:
  rules:
  - host: file.lan
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: filebrowser
            port:
              number: 80
```