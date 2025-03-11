---
title: "Channel"
date: 2025-03-05T12:46:50+08:00
---

### channel 数据结构

channel 被用来实现 goroutine 间的通信，以通信的方式共享内存。

如下代码使用 make 函数会在 `堆上` 分配一个 `runtime.hchan` 类型的数据结构并初始化，ch 是存在于 f 函数栈帧上的一个指针，指向堆上的 hchan 数据结构。

```golang
func f() {
    ch := make(chan int)
    ...
}
```

channel 分为 无缓冲 和 有缓冲 两种。对于有缓冲的 channel 来说，使用循环数组 `buf` 来存储数据。

[Golang 图解channel之数据结构](https://mp.weixin.qq.com/s/6ZEGtXRGKm2qP5b-rGLyVg)

### select 和 channel 机制

> 通过 `gouroutine` 和 `channel` 实现并发中基于通信的内存同步, `channel` 还可以和 `select`、`cancel`、`timeout` 结合使用

channel 分为不带缓冲和带缓冲的，不带缓冲的可以认为是“同步模式”，带缓冲的可以认为是“异步模式”。

channel 的数据结构如下，包含一个 循环数组 buf 存储缓存中的数据 和当前读写在数组中的索引，以及缓存大小，还有一个阻塞

```golang
type hchan struct {
	qcount   uint           // chan 中元素数量, 对于无缓冲的为 0, 数据直接从发送方传递给接收方
	dataqsiz uint           // chan 底层循环数组的大小, 对于无缓冲的为 0
	buf      unsafe.Pointer // 指向底层循环数组的指针, 只针对有缓冲的 channel
	elemsize uint16 // chan 中元素大小
	closed   uint32 // chan 是否关闭的标志
	timer    *timer // timer feeding this chan
	elemtype *_type // chan 中元素类型
	sendx    uint   // 下一个要发送元素在循环数组中的索引
	recvx    uint   // 下一个要接收元素在循环数组中的索引
	recvq    waitq  // 阻塞的尝试从此 channel 接收数据的 goroutine, sudog 双向链表
	sendq    waitq  // 阻塞的尝试向此 channel 发送数据的 goroutine, sudog 双向链表
	lock mutex      // 保护 hchan 所有字段的锁
}

type waitq struct {
	first *sudog
	last  *sudog
}
```

阻塞模式和非阻塞模式：由 select 是否包含 default 确定

非阻塞模式在获取不到数据或者写入不了时会直接返回

阻塞模式下会调用 gopark 函数挂起 goroutine，那么问题来了，阻塞模式 select 有很多 channel 时，挂起的 goroutine 信息会被写入到所有 channel 的对应 recvq 和 sendq 中？。

##### 1. 阻塞模式下(select无default / 直接从channel读写)

阻塞模式下发送方写入数据到channel时没有使用 buf 循环数组，直接写入到接收方的接收变量地址中

1.1 无缓冲 channel

读：如果 sendq 中没有等待发送的 sudog，则阻塞，并将当前 goroutine 和 接收数据的变量地址填入到 sudog 中加入阻塞的读队列 recvq，当有要发送时

写：如果

1.2 有缓冲 channel

##### 2. 非阻塞模式下(select有default)

2.1 无缓冲 channel

2.2 有缓冲 channel