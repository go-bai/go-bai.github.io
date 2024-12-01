---
title: "CRI 工作原理"
date: 2024-11-17T20:30:12+08:00
draft: true
toc: true
tags: [k8s,cri]
---

## 关于 CRI

CRI 全称为 `Container Runtime Interface`, 容器运行时接口

https://github.com/kubernetes/cri-api

containerd 的 `criService` 有实现下面这个 `RuntimeServiceServer`

```golang
// RuntimeServiceServer is the server API for RuntimeService service.
type RuntimeServiceServer interface {
	// Version returns the runtime name, runtime version, and runtime API version.
	Version(context.Context, *VersionRequest) (*VersionResponse, error)
	// RunPodSandbox creates and starts a pod-level sandbox. Runtimes must ensure
	// the sandbox is in the ready state on success.
	RunPodSandbox(context.Context, *RunPodSandboxRequest) (*RunPodSandboxResponse, error)
	// StopPodSandbox stops any running process that is part of the sandbox and
	// reclaims network resources (e.g., IP addresses) allocated to the sandbox.
	// If there are any running containers in the sandbox, they must be forcibly
	// terminated.
	// This call is idempotent, and must not return an error if all relevant
	// resources have already been reclaimed. kubelet will call StopPodSandbox
	// at least once before calling RemovePodSandbox. It will also attempt to
	// reclaim resources eagerly, as soon as a sandbox is not needed. Hence,
	// multiple StopPodSandbox calls are expected.
	StopPodSandbox(context.Context, *StopPodSandboxRequest) (*StopPodSandboxResponse, error)
	// RemovePodSandbox removes the sandbox. If there are any running containers
	// in the sandbox, they must be forcibly terminated and removed.
	// This call is idempotent, and must not return an error if the sandbox has
	// already been removed.
	RemovePodSandbox(context.Context, *RemovePodSandboxRequest) (*RemovePodSandboxResponse, error)
	// PodSandboxStatus returns the status of the PodSandbox. If the PodSandbox is not
	// present, returns an error.
	PodSandboxStatus(context.Context, *PodSandboxStatusRequest) (*PodSandboxStatusResponse, error)
	// ListPodSandbox returns a list of PodSandboxes.
	ListPodSandbox(context.Context, *ListPodSandboxRequest) (*ListPodSandboxResponse, error)
	// CreateContainer creates a new container in specified PodSandbox
	CreateContainer(context.Context, *CreateContainerRequest) (*CreateContainerResponse, error)
	// StartContainer starts the container.
	StartContainer(context.Context, *StartContainerRequest) (*StartContainerResponse, error)
	// StopContainer stops a running container with a grace period (i.e., timeout).
	// This call is idempotent, and must not return an error if the container has
	// already been stopped.
	// The runtime must forcibly kill the container after the grace period is
	// reached.
	StopContainer(context.Context, *StopContainerRequest) (*StopContainerResponse, error)
	// RemoveContainer removes the container. If the container is running, the
	// container must be forcibly removed.
	// This call is idempotent, and must not return an error if the container has
	// already been removed.
	RemoveContainer(context.Context, *RemoveContainerRequest) (*RemoveContainerResponse, error)
	// ListContainers lists all containers by filters.
	ListContainers(context.Context, *ListContainersRequest) (*ListContainersResponse, error)
	// ContainerStatus returns status of the container. If the container is not
	// present, returns an error.
	ContainerStatus(context.Context, *ContainerStatusRequest) (*ContainerStatusResponse, error)
	// UpdateContainerResources updates ContainerConfig of the container synchronously.
	// If runtime fails to transactionally update the requested resources, an error is returned.
	UpdateContainerResources(context.Context, *UpdateContainerResourcesRequest) (*UpdateContainerResourcesResponse, error)
	// ReopenContainerLog asks runtime to reopen the stdout/stderr log file
	// for the container. This is often called after the log file has been
	// rotated. If the container is not running, container runtime can choose
	// to either create a new log file and return nil, or return an error.
	// Once it returns error, new container log file MUST NOT be created.
	ReopenContainerLog(context.Context, *ReopenContainerLogRequest) (*ReopenContainerLogResponse, error)
	// ExecSync runs a command in a container synchronously.
	ExecSync(context.Context, *ExecSyncRequest) (*ExecSyncResponse, error)
	// Exec prepares a streaming endpoint to execute a command in the container.
	Exec(context.Context, *ExecRequest) (*ExecResponse, error)
	// Attach prepares a streaming endpoint to attach to a running container.
	Attach(context.Context, *AttachRequest) (*AttachResponse, error)
	// PortForward prepares a streaming endpoint to forward ports from a PodSandbox.
	PortForward(context.Context, *PortForwardRequest) (*PortForwardResponse, error)
	// ContainerStats returns stats of the container. If the container does not
	// exist, the call returns an error.
	ContainerStats(context.Context, *ContainerStatsRequest) (*ContainerStatsResponse, error)
	// ListContainerStats returns stats of all running containers.
	ListContainerStats(context.Context, *ListContainerStatsRequest) (*ListContainerStatsResponse, error)
	// PodSandboxStats returns stats of the pod sandbox. If the pod sandbox does not
	// exist, the call returns an error.
	PodSandboxStats(context.Context, *PodSandboxStatsRequest) (*PodSandboxStatsResponse, error)
	// ListPodSandboxStats returns stats of the pod sandboxes matching a filter.
	ListPodSandboxStats(context.Context, *ListPodSandboxStatsRequest) (*ListPodSandboxStatsResponse, error)
	// UpdateRuntimeConfig updates the runtime configuration based on the given request.
	UpdateRuntimeConfig(context.Context, *UpdateRuntimeConfigRequest) (*UpdateRuntimeConfigResponse, error)
	// Status returns the status of the runtime.
	Status(context.Context, *StatusRequest) (*StatusResponse, error)
	// CheckpointContainer checkpoints a container
	CheckpointContainer(context.Context, *CheckpointContainerRequest) (*CheckpointContainerResponse, error)
	// GetContainerEvents gets container events from the CRI runtime
	GetContainerEvents(*GetEventsRequest, RuntimeService_GetContainerEventsServer) error
	// ListMetricDescriptors gets the descriptors for the metrics that will be returned in ListPodSandboxMetrics.
	// This list should be static at startup: either the client and server restart together when
	// adding or removing metrics descriptors, or they should not change.
	// Put differently, if ListPodSandboxMetrics references a name that is not described in the initial
	// ListMetricDescriptors call, then the metric will not be broadcasted.
	ListMetricDescriptors(context.Context, *ListMetricDescriptorsRequest) (*ListMetricDescriptorsResponse, error)
	// ListPodSandboxMetrics gets pod sandbox metrics from CRI Runtime
	ListPodSandboxMetrics(context.Context, *ListPodSandboxMetricsRequest) (*ListPodSandboxMetricsResponse, error)
	// RuntimeConfig returns configuration information of the runtime.
	// A couple of notes:
	//   - The RuntimeConfigRequest object is not to be confused with the contents of UpdateRuntimeConfigRequest.
	//     The former is for having runtime tell Kubelet what to do, the latter vice versa.
	//   - It is the expectation of the Kubelet that these fields are static for the lifecycle of the Kubelet.
	//     The Kubelet will not re-request the RuntimeConfiguration after startup, and CRI implementations should
	//     avoid updating them without a full node reboot.
	RuntimeConfig(context.Context, *RuntimeConfigRequest) (*RuntimeConfigResponse, error)
}
```