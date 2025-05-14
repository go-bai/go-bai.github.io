---
title: "k8s namespaces"
date: 2024-08-05T23:07:12+08:00
---

> 一个 namespace 将全局系统资源封装在一个抽象中，使得 namespace 内的进程看起来像是拥有该全局资源的独立实例。
> 对全局资源的更改只对属于同一 namespace 的其他进程可见。

Linux 上可用的 namespace 有:

| namespace 类型 | 隔离内容                          |
|----------------|-----------------------------------|
| cgroup         | Cgroup 根目录            |
| ipc            | System V IPC, POSIX 消息队列 |
| network        | 网络设备、协议栈、端口等 |
| mount          | 挂载点                     |
| pid            | 进程 ID                      |
| time           | 启动时间和单调时钟        |
| user           | 用户和组 ID               |
| uts            | 主机名和 NIS 域名     |