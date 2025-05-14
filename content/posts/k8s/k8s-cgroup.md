---
title: "k8s cgroups"
date: 2024-08-05T23:07:04+08:00
---

目前主要用 cgroup v2, 下面记录 k8s 如何通过 cgroup v2 管理 cpu 和 memory 资源

## k8s 使用 cgroup 对容器进行资源管理

1. kubelet 启动时会创建不同 QOS 级别的 root cgroup

- `Guaranteed`: `/sys/fs/cgroup/kubepods.slice/`
- `Burstable`: `/sys/fs/cgroup/kubepods.slice/kubepods-burstable.slice`
- `BestEffort`: `/sys/fs/cgroup/kubepods.slice/kubepods-besteffort.slice`

2. kubelet 通过 CRI 调用 container runtime 创建 sandbox 和 container

这里有个注意点：根据 pod QOS 类型不同, cgroup 创建的目录也不一样, 但是 container runtime 是不知道 kubelet 定义的 QOS 级别的, 所以 kubelet 通过 CRI 调用 container runtime 时会携带 `CgroupParent` 来指定对应 QOS 对应的 cgroup parent.

最终 container runtime 调用 runc 创建 sandbox 和 container, 并且会设置对应的 cgroup 和设置 `cpu.max` 与 `memory.max`, 将 sandbox 和 container 启动进程的 PID 添加进 `cgroup.procs`

> 进程添加进 `cgroup.procs` 后, `cgroup` 会将进程创建的子进程也自动添加到 `cgroup.procs` 中, 并且在进程结束后也会自动从 `cgroup.procs` 清除.

## 查找进程所在 cgroup 根路径

进程 ID 可以通过 `crictl ps` 与 `crictl inspect <container-id> | grep pid` 获取

如进程 ID 为 1227962

```bash
# cat /proc/1227962/cgroup
0::/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podf4bb00c6_a390_4762_860a_643decfd755c.slice/cri-containerd-d2055ddb438f205ccf867146abbf35cc8e3814ebb50eb759e7bff5d5940fb378.scope
```

这里的 `0::` 表示统一的 cgroup v2 层级, 查找 cgroup v2 挂载点:

```bash
# mount | grep cgroup
cgroup2 on /sys/fs/cgroup type cgroup2 (rw,nosuid,nodev,noexec,relatime)
```

所以进程所在 cgroup 根路径如下:

`/sys/fs/cgroup/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podf4bb00c6_a390_4762_860a_643decfd755c.slice/cri-containerd-d2055ddb438f205ccf867146abbf35cc8e3814ebb50eb759e7bff5d5940fb378.scope`

```bash
# cat /sys/fs/cgroup/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podf4bb00c6_a390_4762_860a_643decfd755c.slice/cri-containerd-d2055ddb438f205ccf867146abbf35cc8e3814ebb50eb759e7bff5d5940fb378.scope/cpu.max
200000 100000
# cat /sys/fs/cgroup/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podf4bb00c6_a390_4762_860a_643decfd755c.slice/cri-containerd-d2055ddb438f205ccf867146abbf35cc8e3814ebb50eb759e7bff5d5940fb378.scope/memory.max
4294967296
```

可以看出:

- cpu: 2核
- memory: 4Gi