---
title: "Controller Runtime"
date: 2024-06-01T10:42:13+08:00
draft: true
toc: true
tags: [informer,controller,workqueue]
---

> [controller-runtime](https://github.com/kubernetes-sigs/controller-runtime)是在[client-go/tools/cache](https://github.com/kubernetes/client-go/tree/master/tools/cache)和[client-go/util/workqueue](https://github.com/kubernetes/client-go/tree/master/util/workqueue)的基础上实现的, 了解`client-go/tools/cache`和`client-go/util/workqueue`对理解`controller-runtime`很有帮助

## 介绍informer

带着问题看

## 一些问题

问题1: 更新local store缓存和出发reconcile是否有先后顺序

问题2: 同一个crd object会不会同时被reconcile

这个全靠Queue数据结构设计的精妙, 保证了正在执行的reconcile不会处理相同的object



问题3: 如何解决进入reconcile之后读到的是旧数据的问题

