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
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false
    probeSelectorNilUsesHelmValues: false
    scrapeConfigSelectorNilUsesHelmValues: false
    serviceMonitorSelectorNilUsesHelmValues: false
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

### 配置说明

有一个相关 issue 讨论：[servicemonitor not being discovered](https://github.com/prometheus-operator/kube-prometheus/issues/1392)

```yaml
prometheus:
  prometheusSpec:
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false
    probeSelectorNilUsesHelmValues: false
    scrapeConfigSelectorNilUsesHelmValues: false
    serviceMonitorSelectorNilUsesHelmValues: false
```

如果没有配置上面这些，在相关 selector 为空时，就会使用 `release: kube-prometheus-stack` 作为默认的，自己创建的 `ServiceMonitor` 等资源如果没有设置此 label 就会被会被自动服务发现。比较坑人!!!

```yaml
# kubectl -n monitoring get prometheus -oyaml
apiVersion: v1
items:
- apiVersion: monitoring.coreos.com/v1
  kind: Prometheus
    name: kube-prometheus-stack-prometheus
    namespace: monitoring
  spec:
    podMonitorNamespaceSelector: {}
    podMonitorSelector:
      matchLabels:
        release: kube-prometheus-stack
    probeNamespaceSelector: {}
    probeSelector:
      matchLabels:
        release: kube-prometheus-stack
    ruleNamespaceSelector: {}
    ruleSelector:
      matchLabels:
        release: kube-prometheus-stack
    scrapeConfigNamespaceSelector: {}
    scrapeConfigSelector:
      matchLabels:
        release: kube-prometheus-stack
    serviceMonitorNamespaceSelector: {}
    serviceMonitorSelector:
      matchLabels:
        release: kube-prometheus-stack
```

## 配置 grafana dashboard

导入一个查看 node exporter 的 dashboard

https://grafana.com/grafana/dashboards/16098-node-exporter-dashboard-20240520-job/

