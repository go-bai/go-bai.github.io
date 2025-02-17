---
title: "Node Exporter"
date: 2024-07-03T22:39:59+08:00
draft: false
toc: true
tags: [prometheus, node-exporter]
---

## node-exporter 安装

### 生成账号密码的 bcrypt hash

```bash
apt install apache2-utils -y
```

生成一个账号密码的 bcrypt hash

- `-B` 强制使用 bcrypt 算法
- `-C 10` 指定 bcrypt 的 cost 值为 10, golang bcrypt 默认 cost 值也为 10

注意修改下面的 `username` 和 `password` 为你要设置的账号密码

```bash
# htpasswd -nbBC 10 username password
username:$2y$10$poDYDLemE3r95gcQ.h8FdODudFaFZhwZCSX1RTwpI2s8V4Mwm0.lO
```

#### 关于 bcrypt

格式为 `$2<a/b/x/y>$[cost]$[22 character salt][31 character hash]`

例如

```bash
$2y$10$poDYDLemE3r95gcQ.h8FdODudFaFZhwZCSX1RTwpI2s8V4Mwm0.lO
\__/\/ \____________________/\_____________________________/
Alg Cost      Salt                        Hash
```

### 运行 node-exporter

1. 创建 `prometheus` 配置文件 `/etc/prometheus/web.yml`
2. 创建 `docker-compose.yml` 文件
3. 运行 docker compose

```bash
PASS='$2y$10$poDYDLemE3r95gcQ.h8FdODudFaFZhwZCSX1RTwpI2s8V4Mwm0.lO'
mkdir -p /etc/prometheus

cat <<EOF> /etc/prometheus/web.yml
basic_auth_users:
  # username: password
  prometheus: ${PASS}
EOF

cat <<EOF> /etc/prometheus/docker-compose.yml
services:
  node-exporter:
    image: quay.io/prometheus/node-exporter:latest
    container_name: node-exporter
    command: 
      - "--path.rootfs=/host"
      - "--web.config.file=/etc/prometheus/web.yml"
    network_mode: "host"
    pid: host
    restart: always
    volumes:
      - '/:/host:ro,rslave'
      - /etc/prometheus/web.yml:/etc/prometheus/web.yml
EOF

docker compose -f /etc/prometheus/docker-compose.yml up -d
```

## 在 prometheus 中配置指标收集

### 方式一：直接修改 prometheus 配置

修改 `kube-prometheus-stack` chart 配置并更新，或者直接修改保存配置的 configmap 中的 job 配置, 记得修改 `{EDIT_HERE}` 为实际值

```bash
cat <<EOF> custom_values.yaml
# prometheus service
prometheus:
  prometheusSpec:
    additionalScrapeConfigs:
      - job_name: 'node-exporter-external'
        basic_auth:
          username: {EDIT_HERE} # 这里是明文账号密码
          password: {EDIT_HERE}
        static_configs:
          - targets:
            - '{EDIT_HERE}:9100'
  service:
    type: NodePort

# grafana service
grafana:
  service:
    type: NodePort
EOF

helm upgrade  --install --create-namespace --namespace monitoring kube-prometheus-stack -f custom-values.yaml prometheus-community/kube-prometheus-stack
```

### 方式二：配置 `ServiceMonitor` 进行自动服务发现

把拉取 metrics 时需要的认证信息保存在 secret 中，然后创建 smon(ServiceMonitor)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: node-exporter-external
  namespace: monitoring
data:
  username: {EDIT_HERE} # 这里是 base64 后的账号密码
  password: {EDIT_HERE}
type: Opaque
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: node-exporter-external
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames:
    - monitoring
  selector:
    matchLabels:
      app: node-exporter-external
  jobLabel: app
  endpoints:
  - port: metrics
    path: /metrics
    interval: 5s
    basicAuth:
      username:
        name: node-exporter-external
        key: username
      password:
        name: node-exporter-external
        key: password
```

然后创建指向 node-expoter 服务的 endpoint 和同名 service

```yaml
apiVersion: v1
kind: Endpoints
metadata:
  labels:
    app: node-exporter-external # 用来被 smon select
  name: node-exporter-external
  namespace: monitoring
subsets: # 所有 node exporter 地址信息
- addresses:
  - ip: 192.168.1.100
    nodeName: home
  ports:
  - name: metrics
    port: 9100
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: node-exporter-external # 用来设置 job 名称
  name: node-exporter-external
  namespace: monitoring
spec:
  ports:
  - name: metrics
    port: 9100
    targetPort: metrics
```