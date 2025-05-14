---
title: "CRI 工作原理"
date: 2024-11-17T20:30:12+08:00
---

## 关于 CRI

CRI 全称为 `Container Runtime Interface` (容器运行时接口), 是 `kubelet` 与 容器运行时进行通讯的主要协议。

是 k8s 根据 [OCI runtime-spec](https://github.com/opencontainers/runtime-spec/releases)

![kubelet-cri](/posts/k8s/imgs/kubelet-cri.drawio.png)

[cri-api](https://github.com/kubernetes/cri-api) 主要定义了六个接口:

```bash
staging/src/k8s.io/cri-api/
├── pkg
│   ├── apis
│   │   ├── runtime
│   │   │   └── v1
│   │   │       ├── api.pb.go    {RuntimeServiceClient RuntimeServiceServer ImageServiceClient ImageServiceServer}
│   │   │       ├── api.proto
│   │   │       └── constants.go
│   │   ├── services.go          {RuntimeService ImageManagerService}
```
