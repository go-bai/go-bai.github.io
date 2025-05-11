---
title: "Go GMP 模型"
date: 2025-03-05T13:07:55+08:00
# bookComments: false
# bookSearchExclude: false
---

## CSP

CSP(Communicating Sequential Processes) 被认为是 Go 在并发编程中成功的关键，论文指出应该重视 input 和 output 原语，尤其是并发编程的代码。

## GMP介绍

G M P 是 Go 调度器的三个核心组件

### G 对应 goroutine, 属于用户线程或绿色线程

```golang
type g struct {
	stack       stack   // goroutine 使用的栈，存储了栈的范围 [lo, hi)
	m           *m      // 当前与 g 绑定的 m
	sched       gobuf   // goroutine 的运行现场, 存储各种寄存器的值，如 PC、SP等寄存器，M恢复现场时需要用到
}
```

### M 对应内核线程

M 代表一个工作线程或者说系统线程，G需要调度到M上才能执行，和 P 绑定去获取 G 来执行。

它保存了 M 自身使用的栈信息，当前正在M上执行的G信息，与之绑定的 P 信息。

```golang
// m 代表工作线程，保存了自身使用的栈信息
type m struct {
	// 记录工作线程（也就是内核线程）使用的栈信息。在执行调度代码时需要使用
	// 执行用户 goroutine 代码时，使用用户 goroutine 自己的栈，因此调度时会发生栈的切换
	g0      *g     // goroutine with scheduling stack/
	// 通过 tls 结构体实现 m 与工作线程的绑定
	// 这里是线程本地存储
	tls           [6]uintptr // thread-local storage (for x86 extern register)
	// 当前工作线程绑定的 p
	p             puintptr // attached p for executing go code (nil if not executing go code)
	// 工作线程 id
	thread        uintptr // thread handle
	// 记录所有工作线程的链表
	alllink       *m // on allm
}
```

### P 是调度队列，包含缓存信息

P 取 processor 首字母，为 M 的执行提供上下文，保存 M 执行 G 时的一些资源，例如本地可执行 G 队列、memory cache等。一个M只有绑定P才可以执行goroutine，当M阻塞时，整个P会被传递给其他M，或者说整个P被接管。

每个 P 都有一个 mcache 用作本地 span 缓存，小对象分配时先从本地 mcache 中获取，没有的话就去 mcentral 获取并设置到 P ，mcentral 中也没有的话就会去 mheap 申请。

```golang
// p 保存 go 运行时所必须的资源
type p struct {
	lock mutex
	
	// 指向绑定的 m，如果 p 是 idle 的话，那这个指针是 nil
	m           muintptr   // back-link to associated m (nil if idle)
	
	// Queue of runnable goroutines. Accessed without lock.
	// 本地可运行的队列，不用通过锁即可访问
	runqhead uint32 // 队列头
	runqtail uint32 // 队列尾
	// 使用数组实现的循环队列
	runq     [256]guintptr
	
	// runnext 非空时，代表的是一个 runnable 状态的 G，
	// 这个 G 被 当前 G 修改为 ready 状态，相比 runq 中的 G 有更高的优先级。
	// 如果当前 G 还有剩余的可用时间，那么就应该运行这个 G
	// 运行之后，该 G 会继承当前 G 的剩余时间
	runnext guintptr
}
```

#### 关于 work stealing 机制

每个 P 与一个 M 绑定，M 是真正执行 goroutine 的实体，M 从绑定的 P 中的本地队列获取 G 来执行。

当 M 绑定的 P 本地队列 runq 为空时，M 会从全局队列获取到本地队列来执行 G，当从全局队列中也没获取到可执行的 G 时，M 会从其他 P 的本地队列中偷取一半 G 来执行，被称为 work stealing 机制。