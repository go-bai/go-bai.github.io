---
title: "CSI 工作原理"
date: 2024-11-04T22:07:17+08:00
draft: false
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

创建 pv 时会设置 `pv.spec.claimRef` 字段, 指向对应的 pvc, 随后 pvcontroller 会监听到 pv 的 `claimRef` 字段被设置然后将 pvc 和 pv 绑定(都变成bound状态).

#### 关于 sc.volumeBindingMode

枚举类型, 有 `WaitForFirstConsumer` 和 `Immediate` 两种

- `Immediate`: pvc 创建后立即 provision 并且 bound, 这个是默认模式
- `WaitForFirstConsumer`: 只有使用此 pvc 的 pod 被调度之后才会去 provision 并且 bound
    - 调度 pod 后会在 pvc 上增加一个注解 `volume.kubernetes.io/selected-node={scheduleResult.SuggestedHost}`
    - 通过 pvc 是否包含此注解并不为空来判断是否 provision

`WaitForFirstConsumer` 一般适用于:

1. 本地盘, 防止卷和pod没创建在同一个节点上
2. 不同 node 对应可用区不同, 需要知道被调度到的 node 对应可用区之后在对应可用区创建存储卷

### external-attacher

watch `VolumeAttachment` 对象, 如果 attacher 字段和从 CSI endpoint 调用 `GetPluginInfo` 获取到的一致, 则触发调用 CSI endpoint 执行 `Controller[Publish|Unpublish]Volume`

一般块存储才会需要 attach/detach 操作, 比如 ceph 的 `rbd`

`VolumeAttachment` 对象是由 `ADController`(AttachDetach Controller) 创建, ADController 会不断的检查每一个 pod 对应的 pv 和这个 pod 所调度到的宿主机之间的挂载情况(node.status.volumesAttached), 针对没有挂载的 pv 创建的 `VolumeAttachment` 中存储以下三个信息

#### 关于 VolumeAttachment

// TODO 

`VolumeAttachment` 对象记录 pv 和 node 的挂载关系, 是由 `ADController`(AttachDetach Controller) 创建和删除

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

## 其他

### PV Controller 作用

负责协调 PV 和 PVC 状态, 负责根据规则绑定 PV 和 PVC

### AD Controller 作用

AD Controller 全称 AttachDetach Controller, 主要负责

1. 创建和删除 VolumeAttachment 对象
2. 更新 `node.status.volumesAttached`

> attachdetach controller 的 reconciler 中调用 csi attacher, 负责创建和删除 VolumeAttachment 对象并等待 attach/detach 成功, 最后更新 `node.status.VolumesAttached`

在 attachdetach controller 的 reconciler 中

```golang
// /pkg/controller/volume/attachdetach/reconciler.go
func (rc *reconciler) reconcile(ctx context.Context) {
    for _, attachedVolume := range rc.actualStateOfWorld.GetAttachedVolumes() {
        // 会调用 Detach
        err = rc.attacherDetacher.DetachVolume(logger, attachedVolume.AttachedVolume, verifySafeToDetach, rc.actualStateOfWorld)
    }
    rc.attachDesiredVolumes(logger)

    // Update Node Status
    err := rc.nodeStatusUpdater.UpdateNodeStatuses(logger)
}

func (rc *reconciler) attachDesiredVolumes(logger klog.Logger) {
    for _, volumeToAttach := range rc.desiredStateOfWorld.GetVolumesToAttach() {
        // 会调用 Attach
        err := rc.attacherDetacher.AttachVolume(logger, volumeToAttach.VolumeToAttach, rc.actualStateOfWorld)
    }
}
```

创建和删除 VolumeAttachment 对象, 等待 external-attacher 监听到后调用 CSI endpoint 执行实际的 attach/detach 操作

```golang
// /pkg/volume/csi/csi_attacher.go
func (c *csiAttacher) Attach(spec *volume.Spec, nodeName types.NodeName) (string, error) {
    // 创建 VolumeAttachment 对象
    _, err = c.k8s.StorageV1().VolumeAttachments().Create(context.TODO(), attachment, metav1.CreateOptions{})
    // Attach and detach functionality is exclusive to the CSI plugin that runs in the AttachDetachController,
	// and has access to a VolumeAttachment lister that can be polled for the current status.
	if err := c.waitForVolumeAttachmentWithLister(spec, pvSrc.VolumeHandle, attachID, c.watchTimeout); err != nil {
		return "", err
	}
    return "", nil
}

func (c *csiAttacher) Detach(volumeName string, nodeName types.NodeName) error {
    // 删除 VolumeAttachment 对象
    if err := c.k8s.StorageV1().VolumeAttachments().Delete(context.TODO(), attachID, metav1.DeleteOptions{}); err != nil {
    }
    // Attach and detach functionality is exclusive to the CSI plugin that runs in the AttachDetachController,
    // and has access to a VolumeAttachment lister that can be polled for the current status.
	return c.waitForVolumeDetachmentWithLister(volID, attachID, c.watchTimeout)
}
```

### kubelet VolumeManager 作用

对于持久卷来说, VolumeManager 负责使用 CSI client 调用 CSI plugin 对 volume 进行 mount/unmount 操作

volume manager 的 reconciler 会先确认该被 unmount 的 volume 被 unmount 掉, 然后确认该被 mount 的 volume 被 mount.

根据 `node.Status.VolumesAttached` 中是否有对应 volume 来判断是否被 attach 成功

### VolumeAttachment 的创建、更新和删除

pod 被调度后，AD Controller 会创建 `VolumeAttachment` 对象，external-attacher 监听到后会执行实际的 attach 操作，操作成功后会更新 `node.Status.VolumesAttached`。

pod 被删除后，如果确认该 volume 不再被该节点上的任何 pod 使用（通过检查 `node.Status.VolumesInUse`），AD Controller 会删除对应的 `VolumeAttachment` 对象，external-attacher 监听到后会执行实际的 detach 操作，操作成功后会从 `node.Status.VolumesAttached` 中移除该记录。

## 参考

- [How to write a Container Storage Interface (CSI) plugin](https://arslan.io/2018/06/21/how-to-write-a-container-storage-interface-csi-plugin/)