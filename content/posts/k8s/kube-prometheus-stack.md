---
title: "安装 Kube Prometheus Stack"
date: 2024-07-03T14:56:03+08:00
draft: false
toc: true
tags: [k8s, kube-prometheus-stack]
---

## 安装 kube-prometheus-stack

使用 helm charts 安装 kube-prometheus-stack

```bash
mkdir -p ~/charts/kube-prometheus-stack
cd ~/charts/kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
# values.yaml 用来查看默认值
helm show values prometheus-community/kube-prometheus-stack > values.yaml
cat <<EOF > custom-values.yaml
prometheus:
  prometheusSpec:
    additionalScrapeConfigs: []
  service:
    type: NodePort

# grafana service
grafana:
  service:
    type: NodePort

alertmanager:
  enabled: false
EOF
helm upgrade --install --create-namespace --namespace monitoring kube-prometheus-stack prometheus-community/kube-prometheus-stack -f custom-values.yaml
```

## 配置 grafana dashboard

导入一个查看 node exporter 的 dashboard

https://grafana.com/grafana/dashboards/16098-node-exporter-dashboard-20240520-job/

