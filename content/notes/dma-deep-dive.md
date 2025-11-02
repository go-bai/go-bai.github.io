---
title: "DMA 从入门到精通：直接内存访问的内核机制"
date: 2024-11-02
tags: ["Linux", "DMA", "内核", "硬件", "性能优化"]
summary: "从硬件原理到内核实现，全面解析 DMA 技术的工作机制、编程接口和性能优化"
weight: 5
---

## 什么是 DMA？

想象一下，你要从图书馆搬书到办公室。有两种方式：

1. **传统方式（CPU 拷贝）**：你亲自一本一本地搬，期间不能做其他事情
2. **DMA 方式**：你雇一个搬运工，告诉他从哪搬到哪，然后你就可以去做别的事了

DMA（Direct Memory Access，直接内存访问）就是计算机中的"搬运工"——让硬件设备在不占用 CPU 的情况下，直接读写内存。

### 为什么需要 DMA？

在没有 DMA 之前，数据传输必须经过 CPU：

```
磁盘 → CPU 寄存器 → 内存 (需要 CPU 参与每个字节的传输)
```

这样做的问题：
- **CPU 被占用**：传输大量数据时 CPU 无法做其他工作
- **效率低下**：CPU 的计算能力被浪费在简单的数据搬运上
- **性能瓶颈**：数据传输速度受限于 CPU 的处理速度

有了 DMA 之后：

```
磁盘 → DMA 控制器 → 内存 (CPU 只需设置，不参与实际传输)
```

## DMA 的工作原理

### 基本组件

一个完整的 DMA 系统包含：

1. **DMA 控制器（DMAC）**：负责协调数据传输的硬件
2. **总线**：连接 CPU、内存、DMA 控制器和 I/O 设备
3. **内存**：数据的源或目的地
4. **I/O 设备**：数据的另一端（如磁盘、网卡）

### DMA 传输流程

```
┌─────────┐      ┌──────────────┐      ┌────────┐
│   CPU   │◄────►│ DMA 控制器   │◄────►│  内存  │
└─────────┘      └──────────────┘      └────────┘
                        ▲
                        │
                        ▼
                  ┌──────────┐
                  │ I/O 设备 │
                  └──────────┘
```

**步骤详解**：

1. **初始化阶段（CPU 参与）**：
   ```c
   // CPU 设置 DMA 控制器
   DMA->source_addr = disk_buffer;      // 源地址
   DMA->dest_addr = memory_buffer;      // 目标地址
   DMA->transfer_size = 4096;           // 传输大小
   DMA->control = DMA_START | DMA_READ; // 启动传输
   ```

2. **传输阶段（CPU 不参与）**：
   - DMA 控制器向 I/O 设备发起读请求
   - 设备将数据放到总线上
   - DMA 控制器从总线读取数据
   - DMA 控制器将数据写入内存
   - 重复上述过程直到传输完成

3. **完成阶段（通知 CPU）**：
   - DMA 控制器发起中断（IRQ）
   - CPU 响应中断，处理后续逻辑

### 总线仲裁：谁来使用总线？

当 DMA 工作时，它需要占用总线传输数据。这就产生了一个问题：CPU 和 DMA 都要用总线，谁优先？

**两种模式**：

1. **周期挪用（Cycle Stealing）**：
   - DMA 在 CPU 不使用总线时"偷偷"传输
   - CPU 优先级更高
   - 传输速度较慢但对 CPU 影响小

2. **突发模式（Burst Mode）**：
   - DMA 一次性传输大块数据
   - DMA 完全占用总线，CPU 被暂停
   - 传输速度快但可能影响系统响应

## Linux 内核中的 DMA

### 内核视角：DMA 的挑战

在 Linux 内核中使用 DMA 面临几个挑战：

#### 1. 地址转换问题

CPU 使用的是**虚拟地址**，但 DMA 控制器只能理解**物理地址**：

```
CPU 看到：      0x7fff12345000 (虚拟地址)
              ↓ (页表转换)
DMA 需要：     0x10234000 (物理地址)
```

内核必须在设置 DMA 前进行地址转换：

```c
// 获取物理地址
dma_addr_t phys_addr = virt_to_phys(virtual_addr);
```

#### 2. 缓存一致性问题

现代 CPU 都有缓存（Cache），这会导致数据不一致：

```
场景 1: DMA 读取（设备 → 内存）
┌─────────┐     ┌───────┐     ┌────────┐
│  设备   │────►│  内存 │     │ Cache  │
└─────────┘     └───────┘     └────────┘
                    新数据        旧数据

问题：CPU 从 Cache 读到的是旧数据！

场景 2: DMA 写入（内存 → 设备）
┌─────────┐     ┌───────┐     ┌────────┐
│  设备   │◄────│  内存 │     │ Cache  │
└─────────┘     └───────┘     └────────┘
                    旧数据        新数据

问题：设备读到的是旧数据，CPU 修改的新数据还在 Cache 中！
```

**解决方案**：缓存刷新操作

```c
// DMA 读取前：使 Cache 无效（让 CPU 从内存读新数据）
dma_sync_single_for_device(dev, dma_addr, size, DMA_FROM_DEVICE);

// DMA 读取后：
dma_sync_single_for_cpu(dev, dma_addr, size, DMA_FROM_DEVICE);

// DMA 写入前：刷新 Cache（将 CPU 的新数据写回内存）
dma_sync_single_for_device(dev, dma_addr, size, DMA_TO_DEVICE);
```

#### 3. 内存区域限制

某些老旧的 DMA 控制器只能访问特定的内存区域：

- **ISA DMA**：只能访问低 16MB 内存（24 位地址线）
- **32 位 DMA**：只能访问低 4GB 内存
- **64 位 DMA**：可以访问全部内存

Linux 定义了 DMA Zone：

```c
// 内核内存区域
ZONE_DMA       // 0-16MB (ISA DMA)
ZONE_DMA32     // 0-4GB  (32位 DMA)
ZONE_NORMAL    // 4GB+   (所有内存)
```

### DMA API：内核编程接口

#### 一致性 DMA 映射（Coherent DMA）

适合需要频繁访问的小块数据（如设备描述符、命令队列）：

```c
// 分配 DMA 一致性内存
void *virt_addr = dma_alloc_coherent(dev, size, &dma_addr, GFP_KERNEL);
// virt_addr: CPU 虚拟地址
// dma_addr:  DMA 物理地址
// 特点：不需要缓存同步操作，硬件保证一致性

// 使用完后释放
dma_free_coherent(dev, size, virt_addr, dma_addr);
```

#### 流式 DMA 映射（Streaming DMA）

适合大块数据的单向传输（如网络数据包、磁盘 I/O）：

```c
// 单个缓冲区
dma_addr_t dma_addr = dma_map_single(dev, buffer, size, DMA_TO_DEVICE);

// 使用 DMA 传输...

// 完成后解除映射
dma_unmap_single(dev, dma_addr, size, DMA_TO_DEVICE);
```

**传输方向**：
- `DMA_TO_DEVICE`：内存 → 设备（如写磁盘）
- `DMA_FROM_DEVICE`：设备 → 内存（如读网卡）
- `DMA_BIDIRECTIONAL`：双向传输

#### Scatter-Gather DMA

将多个不连续的内存块一次性传输，避免多次 DMA 设置：

```c
// 准备 scatter-gather 列表
struct scatterlist sg[3];
sg_init_table(sg, 3);
sg_set_buf(&sg[0], buf1, len1);  // 第一块内存
sg_set_buf(&sg[1], buf2, len2);  // 第二块内存
sg_set_buf(&sg[2], buf3, len3);  // 第三块内存

// 映射整个列表
int nents = dma_map_sg(dev, sg, 3, DMA_TO_DEVICE);

// DMA 控制器会依次传输这些块
// 完成后解除映射
dma_unmap_sg(dev, sg, nents, DMA_TO_DEVICE);
```

### 实战：一个简单的 DMA 驱动示例

```c
#include <linux/dma-mapping.h>
#include <linux/module.h>

// 设备结构
struct my_device {
    struct device *dev;
    void *virt_addr;      // CPU 虚拟地址
    dma_addr_t dma_addr;  // DMA 物理地址
    size_t size;
};

// 初始化 DMA
int my_device_init_dma(struct my_device *mydev, size_t size)
{
    // 1. 设置 DMA 掩码（支持 32 位地址）
    if (dma_set_mask_and_coherent(mydev->dev, DMA_BIT_MASK(32))) {
        dev_err(mydev->dev, "DMA not supported\n");
        return -EIO;
    }

    // 2. 分配 DMA 一致性内存
    mydev->size = size;
    mydev->virt_addr = dma_alloc_coherent(mydev->dev, size,
                                          &mydev->dma_addr,
                                          GFP_KERNEL);
    if (!mydev->virt_addr) {
        dev_err(mydev->dev, "Failed to allocate DMA memory\n");
        return -ENOMEM;
    }

    printk(KERN_INFO "DMA buffer allocated:\n");
    printk(KERN_INFO "  Virtual address: %p\n", mydev->virt_addr);
    printk(KERN_INFO "  DMA address: 0x%llx\n",
           (unsigned long long)mydev->dma_addr);

    return 0;
}

// 启动 DMA 传输（伪代码）
void my_device_start_dma(struct my_device *mydev)
{
    // 设置 DMA 控制器寄存器
    writel(mydev->dma_addr, mydev->regs + DMA_SRC_ADDR);
    writel(mydev->size, mydev->regs + DMA_TRANSFER_SIZE);
    writel(DMA_START | DMA_INT_ENABLE, mydev->regs + DMA_CONTROL);
}

// DMA 完成中断处理
irqreturn_t my_device_irq_handler(int irq, void *data)
{
    struct my_device *mydev = data;

    // 检查是否是 DMA 完成中断
    u32 status = readl(mydev->regs + DMA_STATUS);
    if (status & DMA_COMPLETE) {
        // 处理传输完成的数据
        process_dma_data(mydev->virt_addr, mydev->size);

        // 清除中断标志
        writel(DMA_COMPLETE, mydev->regs + DMA_STATUS);

        return IRQ_HANDLED;
    }

    return IRQ_NONE;
}

// 清理 DMA 资源
void my_device_cleanup_dma(struct my_device *mydev)
{
    if (mydev->virt_addr) {
        dma_free_coherent(mydev->dev, mydev->size,
                         mydev->virt_addr, mydev->dma_addr);
    }
}
```

## DMA 性能优化

### 1. 选择合适的 DMA 模式

```c
// 小数据，频繁访问 → 一致性 DMA
void *ring_buffer = dma_alloc_coherent(dev, 4096, &dma_addr, GFP_KERNEL);

// 大数据，单次传输 → 流式 DMA
dma_addr = dma_map_single(dev, data_buffer, 1024*1024, DMA_TO_DEVICE);

// 多个分散的块 → Scatter-Gather
dma_map_sg(dev, sg_list, num_entries, DMA_TO_DEVICE);
```

### 2. 批量传输

```c
// 不好的做法：多次小传输
for (i = 0; i < 100; i++) {
    dma_transfer(small_buffer[i], 4096);  // 每次 4KB
}

// 好的做法：一次大传输
dma_transfer(large_buffer, 400*1024);  // 一次 400KB
```

### 3. 使用 DMA 池

对于频繁分配/释放的小块 DMA 内存：

```c
// 创建 DMA 池
struct dma_pool *pool = dma_pool_create("mypool", dev, size, align, 0);

// 从池中分配
void *addr = dma_pool_alloc(pool, GFP_KERNEL, &dma_addr);

// 归还到池中
dma_pool_free(pool, addr, dma_addr);

// 销毁池
dma_pool_destroy(pool);
```

### 4. 对齐优化

DMA 传输对齐的数据更高效：

```c
// 确保缓冲区对齐到 cache line（通常 64 字节）
void *buffer __attribute__((aligned(64)));

// 或使用内核宏
void *buffer = kmalloc(size, GFP_KERNEL | __GFP_DMA);
```

## 实际应用案例

### 案例 1：网卡驱动中的 DMA

```c
// 网卡接收数据包的流程
1. 驱动分配 sk_buff 和 DMA 缓冲区
   skb = netdev_alloc_skb(dev, PKT_SIZE);
   dma_addr = dma_map_single(dev, skb->data, PKT_SIZE, DMA_FROM_DEVICE);

2. 将 DMA 地址告诉网卡
   writel(dma_addr, nic_regs + RX_DESC_ADDR);

3. 网卡接收到数据包，通过 DMA 写入内存
   (硬件自动完成)

4. 网卡发起中断通知 CPU
   IRQ → irq_handler()

5. 驱动同步 cache，处理数据包
   dma_unmap_single(dev, dma_addr, PKT_SIZE, DMA_FROM_DEVICE);
   netif_rx(skb);  // 传递给网络协议栈
```

### 案例 2：磁盘驱动中的 DMA

```c
// 读取磁盘扇区
1. 准备 scatter-gather 列表（多个内存页）
   for (i = 0; i < nr_pages; i++)
       sg_set_page(&sg[i], pages[i], PAGE_SIZE, 0);

2. 映射到 DMA
   nents = dma_map_sg(dev, sg, nr_pages, DMA_FROM_DEVICE);

3. 配置磁盘控制器
   disk_set_dma_addr(sg_dma_address(&sg[0]));
   disk_set_transfer_size(total_size);
   disk_command(READ_DMA);

4. 等待 DMA 完成
   wait_for_completion(&disk->dma_done);

5. 解除映射
   dma_unmap_sg(dev, sg, nents, DMA_FROM_DEVICE);
```

## 常见问题与调试

### 问题 1：DMA 传输错误

```bash
# 检查 DMA 映射是否成功
if (dma_mapping_error(dev, dma_addr)) {
    pr_err("DMA mapping failed\n");
    return -ENOMEM;
}
```

### 问题 2：数据损坏

通常是缓存一致性问题：

```c
// 确保 DMA 前后正确同步
dma_sync_single_for_device(...);  // DMA 开始前
// DMA 传输...
dma_sync_single_for_cpu(...);     // DMA 完成后
```

### 问题 3：性能不如预期

```bash
# 检查 DMA 模式
cat /proc/interrupts | grep dma

# 检查缓冲区对齐
# 使用 /proc/slabinfo 查看内存分配信息

# 测量传输速度
dd if=/dev/sda of=/dev/null bs=1M count=1000
```

### 调试工具

```bash
# 1. 查看 DMA 使用情况
cat /proc/dma

# 2. 查看设备 DMA 配置
cat /sys/devices/.../dma_mask_bits

# 3. 启用 DMA 调试
echo 1 > /sys/module/dma_api_debug/parameters/debug

# 4. 使用 ftrace 跟踪 DMA 操作
echo 1 > /sys/kernel/debug/tracing/events/dma/enable
cat /sys/kernel/debug/tracing/trace
```

## 总结

DMA 技术的核心价值：

1. **提升性能**：释放 CPU，让其专注于计算任务
2. **降低延迟**：减少数据拷贝次数，提高吞吐量
3. **节省功耗**：CPU 可以进入低功耗状态

使用 DMA 的关键点：

- ✅ 理解虚拟地址和物理地址的转换
- ✅ 注意缓存一致性，正确使用同步 API
- ✅ 根据场景选择合适的 DMA 模式
- ✅ 考虑硬件限制（地址范围、对齐要求）
- ✅ 处理错误情况和异常中断

## 参考资料

- **Linux 内核文档**：
  - Documentation/core-api/dma-api.rst
  - Documentation/core-api/dma-api-howto.rst

- **内核源码**：
  - `kernel/dma/` - DMA 子系统核心代码
  - `include/linux/dma-mapping.h` - DMA API 接口定义

- **书籍**：
  - 《Linux Device Drivers》第 15 章 - Memory Mapping and DMA
  - 《Understanding the Linux Kernel》第 13 章 - I/O Architecture

- **在线资源**：
  - LWN.net: https://lwn.net/Kernel/Index/#Direct_memory_access
  - Linux DMA Engine: https://www.kernel.org/doc/html/latest/driver-api/dmaengine/
