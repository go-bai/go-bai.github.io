---
title: "GC 垃圾回收"
date: 2025-03-05T13:10:46+08:00
# bookComments: false
# bookSearchExclude: false
---

## GC 垃圾回收

分配在栈上的数据，随着函数调用栈的销毁便释放了自身占用的内存，可以被程序重复利用。

协程栈也是从堆上分配的，也在 mheap 管理的 span 中，mspan.spanState 会记录该 span 是用作堆内存还是栈内存。

而分配在堆上的数据，他们占用的内存需要程序主动释放才可以重新使用，否则称为垃圾。

### 三色标记原理

三色标记法，白色，灰色和黑色

1. 垃圾回收开始会把所有数据（栈、堆、数据段）都标记为白色
2. 然后把直接追踪(扫描全局数据区和栈区)到的 root 节点标记为灰色，灰色代表基于当前节点展开的追踪还未完成。
3. 基于某个节点的追踪任务完成后标记为黑色，标识有用并且无需基于它再追踪。
4. 没有灰色节点后意味着标记工作结束。此时有用的数据为黑色，垃圾都是白色，在清除阶段回收这些白色的垃圾即可。

### 混合写屏障

通过 `混合写屏障` 防止GC过程中并发修改对象的问题。

- `混合写屏障` 继承了插入写屏障的优点，起始时无需 STW 打快照，直接并发扫描垃圾即可
- `混合写屏障` 继承了删除写屏障的优点，赋值器是黑色赋值器，GC期间，任何在栈上创建的新对象，均为黑色。扫描过后就不需要扫描了，这样就消除了插入写屏障最后 STW 的重新扫描栈了。
- `混合写屏障` 扫描栈虽然不用 STW，但是扫描某一个具体的栈的时候，还是要停止这个 goroutine 赋值器的工作（针对一个 goroutine 来说，是暂停扫的，要么全灰，要么全黑，是原子状态切换的）

### GC 触发时机

1. 主动触发：调用 `runtime.GC`
2. 被动触发：使用系统监控 `sysmon`，该触发条件由 `runtime.forcegcperiod` 控制，默认为 2 分钟。当超过时间没有产生任何 GC 时，强制触发 GC。使用步调算法。。。

### GC 流程

![Go GC: Latency Problem Solved slide no 12](https://agrim123.github.io/images/GC%20Algorithm%20Phases.png)

#### 标记设置 Mark Setup (`STW`)

打开[写入屏障](https://en.wikipedia.org/wiki/Write_barrier)

需要STW, 所有 goroutine 需要暂停工作并执行, 没有抢占之前这里如果存在 `tight loop operation` 会消耗很长等待的时间.

#### 并发标记 Marking Concurrent

一旦写入屏障打开, 并发标记就开始工作, 标记阶段主要是标记出还在使用的堆内存.

回收器(`collector`) 会占用 `25%` 的可用 CPU 容量, 使用 Goroutine 执行回收工作并且使用和应用 Goroutine 相同的 P 和 M.

标记流程为: 

TODO 补充三色标记流程

1. 寻找根节点, 把 `全局数据区` 和 `栈区` 的节点标记为 `灰色`

标记辅助(Mark Assist)可以用来加速标记阶段执行. 通过 `runtime.gcAssistAlloc` 函数实现, 当某个goroutine分配内存过快时，调度器会强制其执行更多标记工作

#### 标记终止 Mark Termination (`STW`)

关闭写入屏障, 执行各种清理任务并计算下一个回收目标.

应用程序恢复到全功率.

#### 并发清除 Sweeping Concurrent

清除是指回收 `reclaim` 与堆内存中未被标记为在使用的值关联的内存.

> 注意这里的 reclaim 不一定是被操作系统立即回收的, 表现形式就是回收了, 但是进程占用的内存没少.

TODO: 补充 reclaim 的操作系统相关接口调用

### GC 对应用性能影响

1. 窃取 25% CPU 容量
2. STW 延时

## 参考

- [Go's garbage collector](https://agrim123.github.io/posts/go-garbage-collector.html)