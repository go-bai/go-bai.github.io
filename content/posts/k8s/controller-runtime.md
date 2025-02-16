---
title: "Controller Runtime"
date: 2024-06-01T10:42:13+08:00
draft: false
toc: true
tags: [informer,controller,workqueue]
---

> [controller-runtime](https://github.com/kubernetes-sigs/controller-runtime)是在[client-go/tools/cache](https://github.com/kubernetes/client-go/tree/master/tools/cache)和[client-go/util/workqueue](https://github.com/kubernetes/client-go/tree/master/util/workqueue)的基础上实现的, 了解`client-go/tools/cache`和`client-go/util/workqueue`对理解`controller-runtime`很有帮助

## informer 的工作机制是什么

1. `Reflector` 从 `kube-apiserver` 中获取资源对象, 更新到 `DeltaFIFO` 中
2. Informer 从 DeltaFIFO 中获取资源对象, 更新到 `local cache` 中, 然后执行注册的 EventHandler

自定义控制器会注册 `AddFunc`, `UpdateFunc`, `DeleteFunc` 等事件处理器, 这些事件会添加对象到 WorkQueue 中, 然后从 WorkQueue 中获取对象, 触发 reconcile

### 同一个 crd object 会不会同时被 reconcile

这个全靠Queue数据结构设计的精妙, 保证了正在执行的reconcile不会处理相同的object

向queue中增加object之前会检查是否有次object存在于queue中，如果不存在则加入dirty set，如果也不存在于processing set才会加入queue中，当processing中的处理完成之后（调用Done），会将object从processing set种移除，如果次object在处理过程中加入到了dirty set，则将object再次加入到queue中
https://www.cnblogs.com/daniel-hutao/p/18010835/k8s_clientgo_workqueue

有几种队列，Queue，DelayingQueue，RateLimitingQueue

### `reconcile` 时会读到旧数据吗，如何解决

因为读写分离，更新是直接更新 `kube-apiserver`，读是从 `indexer(local cache)` 中，所以读到的有可能是陈旧的数据。

My cache might be stale if I read from a cache! How should I deal with that?

在更新或patch status之后，通过wait.Pool(100ms, 2s, func()(bool, error))校验cache中的本object数据直至更新

https://github.com/kubernetes-sigs/controller-runtime/blob/main/FAQ.md#q-my-cache-might-be-stale-if-i-read-from-a-cache-how-should-i-deal-with-that

https://github.com/kubernetes/test-infra/blob/8f0f19a905a20ed6f76386e5e11343d4bc2446a7/prow/plank/reconciler.go#L516-L520


