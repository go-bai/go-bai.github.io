---
title: "安装 Rook Ceph"
date: 2024-07-02T14:56:03+08:00
draft: false
---

使用 [RKE2 快速搭建 k8s 集群](../rke2/) 创建的集群

## 安装 rook ceph

使用 helm charts 安装 rook ceph

https://rook.io/docs/rook/latest-release/Helm-Charts/helm-charts/

### 安装 ceph operator

我这里禁用了 cephfs 和 nfs 相关功能

```bash
mkdir -p ~/charts/rook-ceph/ceph-operator
cd ~/charts/rook-ceph/ceph-operator
helm repo add rook-release https://charts.rook.io/release
# values.yaml 用来查看默认值
helm show values rook-release/rook-ceph > values.yaml
cat <<EOF > custom-values.yaml
logLevel: DEBUG
csi:
  enableCephfsDriver: false
  enableCephfsSnapshotter: false
  enableNFSSnapshotter: false
EOF
helm upgrade --install --create-namespace --namespace rook-ceph rook-ceph rook-release/rook-ceph -f custom-values.yaml
```

### 安装 ceph cluster

添加三个 node 上的三个盘作为 osd

```bash
mkdir -p ~/charts/rook-ceph/ceph-cluster
cd ~/charts/rook-ceph/ceph-cluster
helm repo add rook-release https://charts.rook.io/release
# values.yaml 用来查看默认值
helm show values rook-release/rook-ceph-cluster > values.yaml
cat <<EOF > custom-values.yaml
toolbox:
  enabled: true
cephClusterSpec:
  storage:
    useAllNodes: false
    useAllDevices: false
    nodes:
      - name: "k8s-node01"
        devices:
          - name: "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0-0-0-1"
      - name: "k8s-node02"
        devices:
          - name: "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0-0-0-1"
      - name: "k8s-node03"
        devices:
          - name: "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0-0-0-1"
cephFileSystems: []
cephBlockPoolsVolumeSnapshotClass:
  enabled: true
EOF
helm upgrade --install --create-namespace --namespace rook-ceph rook-ceph-cluster rook-release/rook-ceph-cluster -f custom-values.yaml
```

### 查看集群状态

进入 toolbox 容器

```bash
toolbox=$(kubectl -n rook-ceph get pods -l app=rook-ceph-tools -o jsonpath="{.items[0].metadata.name}")
kubectl -n rook-ceph exec -it $toolbox -- bash
```

执行 `ceph status` 查看集群状态, 看到 `HEALTH_OK` 表示集群健康

```bash
# 查看集群状态
$ ceph -s
  cluster:
    id:     2f7e89df-f919-4eab-9fb2-82273c8da466
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum a,b,c (age 13m)
    mgr: a(active, since 12m), standbys: b
    osd: 3 osds: 3 up (since 11m), 3 in (since 12m)
    rgw: 1 daemon active (1 hosts, 1 zones)

  data:
    pools:   10 pools, 121 pgs
    objects: 248 objects, 586 KiB
    usage:   217 MiB used, 1.5 TiB / 1.5 TiB avail
    pgs:     121 active+clean

  io:
    client:   85 B/s rd, 170 B/s wr, 0 op/s rd, 0 op/s wr
```

其他常用 ceph 命令

```bash
# 查看 OSD 状态
ceph osd status
ceph osd df
ceph osd utilization
ceph osd pool stats
ceph osd tree

# 查看 Ceph 容量
ceph df

# 查看 Rados 状态
rados df

# 查看 PG 状态
ceph pg stat
```

#### 访问 ceph dashboard

登陆地址获取, 使用 https 访问, 可以通过 nodeport 访问或者直接和集群容器网络打通, 我这里直接在局域网网关上配了静态路由(类似 host-gw 模式), pod 网络被转发到第一个 node 节点上

```bash
kubectl -n rook-ceph get svc rook-ceph-mgr-dashboard
```

admin 用户名密码获取

```bash
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{.data.password}" | base64 -d
```

#### 连接 s3 服务

获取地址访问

```bash
kubectl -n rook-ceph get svc rook-ceph-rgw-ceph-objectstore
```

获取 ak/sk

```bash
toolbox=$(kubectl -n rook-ceph get pods -l app=rook-ceph-tools -o jsonpath="{.items[0].metadata.name}")
ak=$(kubectl -n rook-ceph exec -it $toolbox -- bash -c "radosgw-admin user info --uid rgw-admin-ops-user | jq -r '.keys[0].access_key'")
sk=$(kubectl -n rook-ceph exec -it $toolbox -- bash -c "radosgw-admin user info --uid rgw-admin-ops-user | jq -r '.keys[0].secret_key'")
echo $ak
echo $sk
```

## 其他问题

### 时间同步问题

> clock skew detected on mon.b, mon.c

如果 k8s node 时间不同步, 会导致 ceph 集群状态异常, 可以通过以下命令同步时间

```bash
$ ceph -s
  cluster:
    id:     2f7e89df-f919-4eab-9fb2-82273c8da466
    health: HEALTH_WARN
            2 mgr modules have recently crashed
```

所有节点设置时间同步

1. 安装 chrony: `apt install chrony -y`
2. 编辑 `/etc/chrony/chrony.conf`, 添加内容 `pool 192.168.1.99 iburst`, 这是我局域网的 ntp server
3. 重启 chrony: `systemctl restart chrony`

### 最近有 crash 问题

> 2 mgr modules have recently crashed

```bash
$ ceph -s
  cluster:
    id:     2f7e89df-f919-4eab-9fb2-82273c8da466
    health: HEALTH_WARN
            2 mgr modules have recently crashed
```

查看并清理 crash 信息

```bash
# 查看 crash 列表
$ ceph crash ls
ID                                                                ENTITY  NEW
2024-11-24T06:08:46.350971Z_23380e67-87a5-492e-bf5c-fd10fd90eb8c  mgr.a    *
2024-11-24T06:45:19.829015Z_66d90350-1476-4a52-9ffc-2a6248884f1d  mgr.a    *
# 查看 crash 详情
$ ceph crash info 2024-11-24T06:08:46.350971Z_23380e67-87a5-492e-bf5c-fd10fd90eb8c
{
    "backtrace": [
        "  File \"/usr/share/ceph/mgr/nfs/module.py\", line 189, in cluster_ls\n    return available_clusters(self)",
        "  File \"/usr/share/ceph/mgr/nfs/utils.py\", line 70, in available_clusters\n    completion = mgr.describe_service(service_type='nfs')",
        "  File \"/usr/share/ceph/mgr/orchestrator/_interface.py\", line 1664, in inner\n    completion = self._oremote(method_name, args, kwargs)",
        "  File \"/usr/share/ceph/mgr/orchestrator/_interface.py\", line 1731, in _oremote\n    raise NoOrchestrator()",
        "orchestrator._interface.NoOrchestrator: No orchestrator configured (try `ceph orch set backend`)"
    ],
    "ceph_version": "18.2.4",
    "crash_id": "2024-11-24T06:08:46.350971Z_23380e67-87a5-492e-bf5c-fd10fd90eb8c",
    "entity_name": "mgr.a",
    "mgr_module": "nfs",
    "mgr_module_caller": "ActivePyModule::dispatch_remote cluster_ls",
    "mgr_python_exception": "NoOrchestrator",
    "os_id": "centos",
    "os_name": "CentOS Stream",
    "os_version": "9",
    "os_version_id": "9",
    "process_name": "ceph-mgr",
    "stack_sig": "922e03f28672a048b4c876242e1e5b1c28a51719b3a09938b8f19b8435ffacbb",
    "timestamp": "2024-11-24T06:08:46.350971Z",
    "utsname_hostname": "rook-ceph-mgr-a-d959864d7-4cckg",
    "utsname_machine": "x86_64",
    "utsname_release": "5.15.0-125-generic",
    "utsname_sysname": "Linux",
    "utsname_version": "#135-Ubuntu SMP Fri Sep 27 13:53:58 UTC 2024"
}
# 清理一天之前的 crash 信息
$ ceph crash prune 1
```

### 如果重装 rook ceph 集群

https://rook.io/docs/rook/latest/Storage-Configuration/ceph-teardown/#delete-the-data-on-hosts

需要清理 `/var/lib/rook` 目录并擦除osd盘的文件系统, 如下 `sdb` 是 osd 盘

```bash
rm -rf /var/lib/rook
wipefs /dev/sdb -a
```
