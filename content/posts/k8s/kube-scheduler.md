---
title: "Kube Scheduler"
date: 2024-12-17T22:07:49+08:00
---

RKE2 自定义[调度器配置](https://kubernetes.io/zh-cn/docs/reference/scheduling/config/)

1. 创建调度器配置文件

`NodeResourcesFit` 是一个调度插件, 检查节点是否拥有 Pod 请求的所有资源, 得分可以使用以下三种策略之一: 
`LeastAllocated` (默认)、`MostAllocated` 和 `RequestedToCapacityRatio`

实现了多个扩展点: `preFilter`、`filter`、`preScore`、`score`

我这里自定义使用 `MostAllocated` 策略, 优选分配比率较高的节点

```yaml
# /etc/rancher/rke2/kube-scheduler-config.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: /var/lib/rancher/rke2/server/cred/scheduler.kubeconfig
profiles:
  - schedulerName: default-scheduler
    pluginConfig:
      - name: NodeResourcesFit
        args:
          scoringStrategy:
            type: MostAllocated
            resources:
              - name: cpu
                weight: 1
              - name: memory
                weight: 1
```

2. 修改 rke2 配置文件

修改 `/etc/rancher/rke2/config.yaml`

```diff
kube-scheduler-arg:
+ - config=/etc/rancher/rke2/kube-scheduler-config.yaml
```

3. 重启 rke2-server

会重新生成 kube-scheduler 的 static pod manifest 文件 `/var/lib/rancher/rke2/agent/pod-manifests/kube-scheduler.yaml`

会挂载 `/etc/rancher/rke2/kube-scheduler-config.yaml` 文件到 pod 中