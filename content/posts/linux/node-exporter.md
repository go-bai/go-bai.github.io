---
title: "Node Exporter"
date: 2024-10-23T22:39:59+08:00
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

## 修改 kube-prometheus-stack chart 配置

修改 `kube-prometheus-stack` chart 配置并更新, 记得修改 `{EDIT_HERE}` 为实际值

```bash
cat <<EOF> values.yaml
# prometheus service
prometheus:
  prometheusSpec:
    additionalScrapeConfigs:
      - job_name: 'host-node-exporter'
        basic_auth:
          username: {EDIT_HERE}
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

helm upgrade  --install --create-namespace --namespace monitoring kube-prometheus-stack -f values.yaml prometheus-community/kube-prometheus-stack
```