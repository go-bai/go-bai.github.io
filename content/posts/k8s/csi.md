---
title: "CSI"
date: 2024-11-04T22:07:17+08:00
draft: false
toc: true
tags: [k8s,csi]
---

## 关于 CSI

CSI 全称为 `Container Storage Interface`, 容器存储接口

要实现一个第三方的 csi driver 需要实现下面的 gRPC service [csi spec](https://github.com/container-storage-interface/spec/blob/master/lib/go/csi/csi_grpc.pb.go)

```golang
// 如果 NodeServer 和 ControllerServer 对应服务运行在不同 pod 中, 那么两个服务都要实现 IdentityServer
type IdentityServer interface {
    // 用来获取插件名称
    GetPluginInfo(context.Context, *GetPluginInfoRequest) (*GetPluginInfoResponse, error)
    GetPluginCapabilities(context.Context, *GetPluginCapabilitiesRequest) (*GetPluginCapabilitiesResponse, error)
    Probe(context.Context, *ProbeRequest) (*ProbeResponse, error)
    mustEmbedUnimplementedIdentityServer()
}

type ControllerServer interface {
    // 创建 volume, 如 ceph 创建一个 rbd 或者 hostpath 创建一个目录
    CreateVolume(context.Context, *CreateVolumeRequest) (*CreateVolumeResponse, error)
    // 删除 volume, 如 ceph 删除一个 rbd 或者 hostpath 删除一个目录
    DeleteVolume(context.Context, *DeleteVolumeRequest) (*DeleteVolumeResponse, error)
    // 将 volume attach 到 node 上, 如 rbd 通过 rbd map 命令 attach, 成功后 node 上会多出一个 rbdx 的 block 设备
    ControllerPublishVolume(context.Context, *ControllerPublishVolumeRequest) (*ControllerPublishVolumeResponse, error)
    // 将 volume 从 node 上 detach, 如 rbd 通过 rbd unmap 命令 detach
    ControllerUnpublishVolume(context.Context, *ControllerUnpublishVolumeRequest) (*ControllerUnpublishVolumeResponse, error)
    ValidateVolumeCapabilities(context.Context, *ValidateVolumeCapabilitiesRequest) (*ValidateVolumeCapabilitiesResponse, error)
    // 列出所有 volume
    ListVolumes(context.Context, *ListVolumesRequest) (*ListVolumesResponse, error)
    GetCapacity(context.Context, *GetCapacityRequest) (*GetCapacityResponse, error)
    ControllerGetCapabilities(context.Context, *ControllerGetCapabilitiesRequest) (*ControllerGetCapabilitiesResponse, error)
    CreateSnapshot(context.Context, *CreateSnapshotRequest) (*CreateSnapshotResponse, error)
    DeleteSnapshot(context.Context, *DeleteSnapshotRequest) (*DeleteSnapshotResponse, error)
    ListSnapshots(context.Context, *ListSnapshotsRequest) (*ListSnapshotsResponse, error)
    ControllerExpandVolume(context.Context, *ControllerExpandVolumeRequest) (*ControllerExpandVolumeResponse, error)
    ControllerGetVolume(context.Context, *ControllerGetVolumeRequest) (*ControllerGetVolumeResponse, error)
    ControllerModifyVolume(context.Context, *ControllerModifyVolumeRequest) (*ControllerModifyVolumeResponse, error)
    mustEmbedUnimplementedControllerServer()
}

// 这些会被 kubelet 调用
type NodeServer interface {
    // format (如果没format), mount 到 node 的 global directory
    NodeStageVolume(context.Context, *NodeStageVolumeRequest) (*NodeStageVolumeResponse, error)
    // umount
    NodeUnstageVolume(context.Context, *NodeUnstageVolumeRequest) (*NodeUnstageVolumeResponse, error)
    // mount --bind 到 pod directory
    NodePublishVolume(context.Context, *NodePublishVolumeRequest) (*NodePublishVolumeResponse, error)
    // umount --bind
    NodeUnpublishVolume(context.Context, *NodeUnpublishVolumeRequest) (*NodeUnpublishVolumeResponse, error)
    NodeGetVolumeStats(context.Context, *NodeGetVolumeStatsRequest) (*NodeGetVolumeStatsResponse, error)
    NodeExpandVolume(context.Context, *NodeExpandVolumeRequest) (*NodeExpandVolumeResponse, error)
    NodeGetCapabilities(context.Context, *NodeGetCapabilitiesRequest) (*NodeGetCapabilitiesResponse, error)
    NodeGetInfo(context.Context, *NodeGetInfoRequest) (*NodeGetInfoResponse, error)
    mustEmbedUnimplementedNodeServer()
}
```

## 关于 Sidecar Containers

[Sidecar Containers](https://kubernetes-csi.github.io/docs/sidecar-containers.html) 是一系列标准容器，用于简化 CSI 插件的开发和部署

它们都有共同的逻辑，watch k8s API，调用第三方 csi driver 执行操作，最后对应的更新 k8s API

这些容器一般作为sidecar和第三方 csi driver 一起部署在同一个 pod 中, 通过 unix socket 通信

| 容器 | 仓库 | 文档 |  
| --- | --- | --- |
| node-driver-registrar | [kubernetes-csi/node-driver-registrar](https://github.com/kubernetes-csi/node-driver-registrar) | [link](https://kubernetes-csi.github.io/docs/node-driver-registrar.html) |
| external-provisioner | [kubernetes-csi/external-provisioner](https://github.com/kubernetes-csi/external-provisioner) | [link](https://kubernetes-csi.github.io/docs/external-provisioner.html) |
| external-attacher | [kubernetes-csi/external-attacher](https://github.com/kubernetes-csi/external-attacher) | [link](https://kubernetes-csi.github.io/docs/external-attacher.html) |
| external-snapshotter | [kubernetes-csi/external-snapshotter](https://github.com/kubernetes-csi/external-snapshotter) | [link](https://kubernetes-csi.github.io/docs/external-snapshotter.html) |
| external-resizer | [kubernetes-csi/external-resizer](https://github.com/kubernetes-csi/external-resizer) | [link](https://kubernetes-csi.github.io/docs/external-resizer.html) |
| livenessprobe | [kubernetes-csi/livenessprobe](https://github.com/kubernetes-csi/livenessprobe) | [link](https://kubernetes-csi.github.io/docs/livenessprobe.html) |

### node-driver-registrar

从 CSI endpoint 拉取 driver 信息(使用 NodeGetInfo), 然后通过 [kubelet plugin registration mechanism](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/pluginmanager/pluginwatcher/README.md) 注册到对应节点的 kubelet 中

表现形式为

```
/var/lib/kubelet/plugins/csi-hostpath/csi.sock
/var/lib/kubelet/plugins_registry/kubevirt.io.hostpath-provisioner-reg.sock
```

### external-provisioner

watch `PersistentVolumeClaim` 对象, 如果一个 pvc 引用了一个 `StorageClass` 并且 `StorageClass` 的 `provisioner` 字段
和从 CSI endpoint 调用 `GetPluginInfo` 获取到的一致，则执行下面逻辑

- 创建 pvc 事件调用 CSI endpoint 执行 `CreateVolume`, 成功创建 volume 后就会创建代表这个 volume 的 `PersistentVolume` 对象
- 删除 pvc 事件调用 CSI endpoint 执行 `DeleteVolume`, 成功删除 volume 后也会删除代表这个 volume 的 `PersistentVolume` 对象

当 pvc 对应的 sc 的 volumeBindingMode 为 `WaitForFirstConsumer` 时, 只有使用此 pvc 的 pod 被调度之后才会去创建 pv

### external-attacher

watch `VolumeAttachment` 对象, 如果 attacher 字段和从 CSI endpoint 调用 `GetPluginInfo` 获取到的一致, 则触发调用 CSI endpoint 执行 `Controller[Publish|Unpublish]Volume`

一般块存储才会需要 attach/detach 操作, 比如 ceph 的 `rbd`

`VolumeAttachment` 对象是由 `ADController`(AttachDetach Controller) 创建, ADController 会不断的检查每一个 pod 对应的 pv 和这个 pod 所调度到的宿主机之间的挂载情况(node.status.volumesAttached), 针对没有挂载的 pv 创建的 `VolumeAttachment` 中存储以下三个信息

- attacher: csi driver 名称
- nodeName: volume应该attach到的主机名称
- source.persistentVolumeName: 要attach的pv的名称

### external-snapshotter

TODO

### external-resizer

TODO

### livenessprobe

TODO

## csi demo

### kubernetes-csi/csi-driver-host-path

[kubevirt/hostpath-provisioner](https://github.com/kubevirt/hostpath-provisioner) 是官方提供的 demo

### kubevirt/hostpath-provisioner 

[kubernetes-csi/csi-driver-host-path](https://github.com/kubernetes-csi/csi-driver-host-path) 是 kubevirt 基于 `kubernetes-csi/csi-driver-host-path` 开发的, 改动不多, 适合学习和使用

## csi 测试工具 `csc`

[csc](https://github.com/rexray/gocsi/tree/master/csc) 是 Container Storage Client

### identity

identity service 相关的

#### GetPluginInfo

```bash
$ csc -e /var/lib/kubelet/plugins/csi-hostpath/csi.sock identity plugin-info
"kubevirt.io.hostpath-provisioner"	"latest"
```

### node

node service 相关的

#### NodeGetInfo

`node-driver-registrar` 向 `kubelet` 注册 CSI plugin 时会调用

```bash
$ csc -e /var/lib/kubelet/plugins/csi-hostpath/csi.sock node get-info
test	0	&csi.Topology{Segments:map[string]string{"topology.hostpath.csi/node":"test"}, XXX_NoUnkeyedLiteral:struct {}{}, XXX_unrecognized:[]uint8(nil), XXX_sizecache:0}
```

### controller

controller service 相关的

#### CreateVolume

external-provisioner 监听到有 pvc 创建时会调用

```bash
$ csc -e /var/lib/kubelet/plugins/csi-hostpath/csi.sock controller create-volume --params storagePool=local --cap MULTI_NODE_MULTI_WRITER,mount,xfs,uid=500,gid=500 pvc-466a771a-a8c7-473e-bca6-780f7663a6cd
"pvc-466a771a-a8c7-473e-bca6-780f7663a6cd"	105226698752	"storagePool"="local"
```

#### ListVolumes

可以看到刚才创建的

```bash
$ csc -e /var/lib/kubelet/plugins/csi-hostpath/csi.sock controller list-volumes
"pvc-466a771a-a8c7-473e-bca6-780f7663a6cd"	105226698752
```

#### NodePublishVolume

kubelet 针对  好像不会调用这个 ?

```bash
$ csc -e /var/lib/kubelet/plugins/csi-hostpath/csi.sock node publish xxx
```

#### DeleteVolume

external-provisioner 监听到有 pvc 被删除时会调用

```bash
$ csc -e /var/lib/kubelet/plugins/csi-hostpath/csi.sock controller delete-volume pvc-466a771a-a8c7-473e-bca6-780f7663a6cd
pvc-466a771a-a8c7-473e-bca6-780f7663a6cd
```

## 参考

- [How to write a Container Storage Interface (CSI) plugin](https://arslan.io/2018/06/21/how-to-write-a-container-storage-interface-csi-plugin/)