---
title: "failed to reserve sandbox name"
date: 2024-08-31T23:18:04+08:00
---

## 问题描述

当 k8s 集群时间发生回退时, 会出现 `failed to reserve sandbox name` 错误.

```bash
...
Aug 31 13:58:38 kind-control-plane kubelet[554]: E0831 13:58:38.610262 	554 log.go:32] "RunPodSandbox from runtime service failed" err="r
pc error: code = Unknown desc = failed to reserve sandbox name \"kube-scheduler-kind-control-plane_kube-system_3ead35239782468d5c21d9cb3933d
bb2_0\": name \"kube-scheduler-kind-control-plane_kube-system_3ead35239782468d5c21d9cb3933dbb2_0\" is reserved for \"e193fd73214c4db18ca31ed
c6aa2591445dba26d77b6df9d8956a9228031689e\""
...
```

## 解决办法

将 `<sandbox-id>` 对应的容器删掉

```bash
crictl stopp <sandbox-id>
crictl rmp <sandbox-id>
```

## 相关 issue

- https://github.com/kubernetes/kubernetes/issues/126514
- https://github.com/containerd/containerd/issues/9459

## 相关 PR

- https://github.com/kubernetes/kubernetes/pull/130551
