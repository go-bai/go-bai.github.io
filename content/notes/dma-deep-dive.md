---
title: "DMA 深度解析：直接内存访问的内核机制与实现"
date: 2025-11-02
tags: ["Linux", "DMA", "内核", "硬件", "性能优化"]
summary: "深入剖析 DMA 硬件架构、Linux 内核 DMA 子系统实现、编程接口及性能优化技术"
weight: 5
---

## DMA 概述

DMA（Direct Memory Access）是一种允许外设直接访问系统内存的硬件机制，无需 CPU 参与数据传输的每个步骤。这种技术显著提升了 I/O 性能，释放 CPU 资源用于其他计算任务。

### 传统 I/O vs DMA

传统的编程式 I/O (Programmed I/O, PIO)：

```
Disk -> CPU Registers -> Memory (CPU involved in every byte transfer)
```

问题：
- CPU 周期浪费在数据搬运上
- CPU 开销导致吞吐量低
- 传输期间 CPU 无法执行其他任务

使用 DMA 后：

```
Disk -> DMA Controller -> Memory (CPU only initiates, not involved in transfer)
```

优势：
- CPU 被释放用于计算
- 更高的 I/O 带宽
- 中断驱动的操作延迟更低

## DMA 硬件架构

### 核心组件

1. **DMA 控制器 (DMAC)**：协调设备和内存之间的数据传输
2. **系统总线**：连接 CPU、内存、DMAC 和外设
3. **内存**：数据的源或目的地
4. **I/O 设备**：外设，如磁盘控制器、网卡

### DMA 传输流程

架构图：

```
+----------+      +---------------+      +---------+
|   CPU    |<---->| DMA Controller|<---->| Memory  |
+----------+      +---------------+      +---------+
                         ^
                         |
                         v
                  +------------+
                  | I/O Device |
                  +------------+
```

传输阶段详解：

1. **初始化阶段（CPU 参与）**：

   ```c
   // CPU programs DMA controller
   DMA->source_addr = disk_buffer;
   DMA->dest_addr = memory_buffer;
   DMA->transfer_size = 4096;
   DMA->control = DMA_START | DMA_READ;
   ```

2. **传输阶段（CPU 空闲）**：
   - DMAC 向设备请求数据
   - 设备将数据放到总线上
   - DMAC 从总线读取数据
   - DMAC 将数据写入内存
   - 重复上述过程直到传输完成

3. **完成阶段（通知 CPU）**：
   - DMAC 发起中断 (IRQ)
   - CPU 处理中断并处理结果

### 总线仲裁

DMA 工作时，需要与 CPU 竞争总线访问权。

传输模式：

1. **周期挪用 (Cycle Stealing)**：
   - DMAC 在 CPU 空闲时"偷取"总线周期
   - CPU 优先级更高
   - 传输较慢但对 CPU 影响最小

2. **突发模式 (Burst Mode)**：
   - DMAC 完全控制总线
   - CPU 在传输期间被暂停
   - 传输更快但可能影响系统响应性

## Linux 内核 DMA 子系统

### 内核 DMA 实现面临的挑战

在 Linux 内核中使用 DMA 面临几个挑战：

#### 1. 地址转换问题

CPU 使用的是**虚拟地址**，但 DMA 控制器只能理解**物理地址**：

```
CPU sees:       0x7fff12345000 (virtual address)
                  ↓ (page table translation)
DMA requires:   0x10234000 (physical address)
```

内核必须在设置 DMA 前进行地址转换：

```c
// Get physical address
dma_addr_t phys_addr = virt_to_phys(virtual_addr);
```

#### 2. 缓存一致性问题

现代 CPU 都有缓存（Cache），这会导致数据不一致：

场景示意：

```
Scenario 1: DMA Read (Device -> Memory)
+---------+     +--------+     +-------+
| Device  |---->| Memory |     | Cache |
+---------+     +--------+     +-------+
                New data       Old data

Problem: CPU reads stale data from cache!

Scenario 2: DMA Write (Memory -> Device)
+---------+     +--------+     +-------+
| Device  |<----| Memory |     | Cache |
+---------+     +--------+     +-------+
                Old data       New data

Problem: Device gets old data, CPU changes still in cache!
```

**解决方案**：缓存刷新操作

同步 API：

```c
// Before DMA read: invalidate cache
dma_sync_single_for_device(dev, dma_addr, size, DMA_FROM_DEVICE);

// After DMA read:
dma_sync_single_for_cpu(dev, dma_addr, size, DMA_FROM_DEVICE);

// Before DMA write: flush cache
dma_sync_single_for_device(dev, dma_addr, size, DMA_TO_DEVICE);
```

#### 3. 内存区域限制

某些老旧的 DMA 控制器只能访问特定的内存区域：

- **ISA DMA**：只能访问低 16MB 内存（24 位地址线）
- **32 位 DMA**：只能访问低 4GB 内存
- **64 位 DMA**：可以访问全部内存

Linux 定义了 DMA Zone：

```c
// Kernel memory zones
ZONE_DMA       // 0-16MB (ISA DMA)
ZONE_DMA32     // 0-4GB  (32-bit DMA)
ZONE_NORMAL    // 4GB+   (all memory)
```

### DMA API：内核编程接口

#### 一致性 DMA 映射（Coherent DMA）

适合需要频繁访问的小块数据（如设备描述符、命令队列）：

API 示例：

```c
// Allocate DMA coherent memory
void *virt_addr = dma_alloc_coherent(dev, size, &dma_addr, GFP_KERNEL);
// virt_addr: CPU virtual address
// dma_addr:  DMA physical address
// Feature: no cache sync needed, hardware guarantees coherency

// Release after use
dma_free_coherent(dev, size, virt_addr, dma_addr);
```

#### 流式 DMA 映射（Streaming DMA）

适合大块数据的单向传输（如网络数据包、磁盘 I/O）：

API 示例：

```c
// Single buffer mapping
dma_addr_t dma_addr = dma_map_single(dev, buffer, size, DMA_TO_DEVICE);

// Perform DMA transfer...

// Unmap after completion
dma_unmap_single(dev, dma_addr, size, DMA_TO_DEVICE);
```

**传输方向**：
- `DMA_TO_DEVICE`：内存 → 设备（如写磁盘）
- `DMA_FROM_DEVICE`：设备 → 内存（如读网卡）
- `DMA_BIDIRECTIONAL`：双向传输

#### Scatter-Gather DMA

将多个不连续的内存块一次性传输，避免多次 DMA 设置：

API 示例：

```c
// Prepare scatter-gather list
struct scatterlist sg[3];
sg_init_table(sg, 3);
sg_set_buf(&sg[0], buf1, len1);  // First block
sg_set_buf(&sg[1], buf2, len2);  // Second block
sg_set_buf(&sg[2], buf3, len3);  // Third block

// Map entire list
int nents = dma_map_sg(dev, sg, 3, DMA_TO_DEVICE);

// DMAC transfers these blocks sequentially
// Unmap after completion
dma_unmap_sg(dev, sg, nents, DMA_TO_DEVICE);
```

### 实战：一个简单的 DMA 驱动示例

完整的内核驱动代码：

```c
#include <linux/dma-mapping.h>
#include <linux/module.h>

// Device structure
struct my_device {
    struct device *dev;
    void *virt_addr;      // CPU virtual address
    dma_addr_t dma_addr;  // DMA physical address
    size_t size;
};

// Initialize DMA
int my_device_init_dma(struct my_device *mydev, size_t size)
{
    // 1. Set DMA mask (support 32-bit address)
    if (dma_set_mask_and_coherent(mydev->dev, DMA_BIT_MASK(32))) {
        dev_err(mydev->dev, "DMA not supported\n");
        return -EIO;
    }

    // 2. Allocate DMA coherent memory
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

// Start DMA transfer (pseudocode)
void my_device_start_dma(struct my_device *mydev)
{
    // Configure DMA controller registers
    writel(mydev->dma_addr, mydev->regs + DMA_SRC_ADDR);
    writel(mydev->size, mydev->regs + DMA_TRANSFER_SIZE);
    writel(DMA_START | DMA_INT_ENABLE, mydev->regs + DMA_CONTROL);
}

// DMA completion interrupt handler
irqreturn_t my_device_irq_handler(int irq, void *data)
{
    struct my_device *mydev = data;

    // Check if DMA complete interrupt
    u32 status = readl(mydev->regs + DMA_STATUS);
    if (status & DMA_COMPLETE) {
        // Process transferred data
        process_dma_data(mydev->virt_addr, mydev->size);

        // Clear interrupt flag
        writel(DMA_COMPLETE, mydev->regs + DMA_STATUS);

        return IRQ_HANDLED;
    }

    return IRQ_NONE;
}

// Cleanup DMA resources
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

根据使用场景选择：

```c
// Small data, frequent access -> Coherent DMA
void *ring_buffer = dma_alloc_coherent(dev, 4096, &dma_addr, GFP_KERNEL);

// Large data, one-time transfer -> Streaming DMA
dma_addr = dma_map_single(dev, data_buffer, 1024*1024, DMA_TO_DEVICE);

// Multiple scattered blocks -> Scatter-Gather
dma_map_sg(dev, sg_list, num_entries, DMA_TO_DEVICE);
```

### 2. 批量传输

对比示例：

```c
// Bad: multiple small transfers
for (i = 0; i < 100; i++) {
    dma_transfer(small_buffer[i], 4096);  // 4KB each time
}

// Good: one large transfer
dma_transfer(large_buffer, 400*1024);  // 400KB once
```

### 3. 使用 DMA 池

对于频繁分配/释放的小块 DMA 内存：

池管理示例：

```c
// Create DMA pool
struct dma_pool *pool = dma_pool_create("mypool", dev, size, align, 0);

// Allocate from pool
void *addr = dma_pool_alloc(pool, GFP_KERNEL, &dma_addr);

// Return to pool
dma_pool_free(pool, addr, dma_addr);

// Destroy pool
dma_pool_destroy(pool);
```

### 4. 对齐优化

DMA 传输对齐的数据更高效：

对齐示例：

```c
// Align buffer to cache line (typically 64 bytes)
void *buffer __attribute__((aligned(64)));

// Or use kernel macro
void *buffer = kmalloc(size, GFP_KERNEL | __GFP_DMA);
```

## 实际应用案例

### 案例 1：网卡驱动中的 DMA

网卡接收数据包的完整流程：

```c
// NIC receive packet flow
// 1. Driver allocates sk_buff and DMA buffer
skb = netdev_alloc_skb(dev, PKT_SIZE);
dma_addr = dma_map_single(dev, skb->data, PKT_SIZE, DMA_FROM_DEVICE);

// 2. Tell NIC the DMA address
writel(dma_addr, nic_regs + RX_DESC_ADDR);

// 3. NIC receives packet, writes to memory via DMA
//    (Hardware handles automatically)

// 4. NIC raises interrupt to notify CPU
//    IRQ -> irq_handler()

// 5. Driver syncs cache, processes packet
dma_unmap_single(dev, dma_addr, PKT_SIZE, DMA_FROM_DEVICE);
netif_rx(skb);  // Pass to network stack
```

### 案例 2：磁盘驱动中的 DMA

读取磁盘扇区的流程：

```c
// Read disk sectors
// 1. Prepare scatter-gather list (multiple memory pages)
for (i = 0; i < nr_pages; i++)
    sg_set_page(&sg[i], pages[i], PAGE_SIZE, 0);

// 2. Map to DMA
nents = dma_map_sg(dev, sg, nr_pages, DMA_FROM_DEVICE);

// 3. Configure disk controller
disk_set_dma_addr(sg_dma_address(&sg[0]));
disk_set_transfer_size(total_size);
disk_command(READ_DMA);

// 4. Wait for DMA completion
wait_for_completion(&disk->dma_done);

// 5. Unmap
dma_unmap_sg(dev, sg, nents, DMA_FROM_DEVICE);
```

## 常见问题与调试

### 问题 1：DMA 传输错误

检查映射是否成功：

```bash
# 检查 DMA 映射是否成功
if (dma_mapping_error(dev, dma_addr)) {
    pr_err("DMA mapping failed\n");
    return -ENOMEM;
}
```

### 问题 2：数据损坏

通常是缓存一致性问题：

同步示例：

```c
// 确保 DMA 前后正确同步
dma_sync_single_for_device(...);  // DMA 开始前
// DMA 传输...
dma_sync_single_for_cpu(...);     // DMA 完成后
```

### 问题 3：性能不如预期

性能分析命令：

```bash
# 检查 DMA 模式
cat /proc/interrupts | grep dma

# 检查缓冲区对齐
# 使用 /proc/slabinfo 查看内存分配信息

# 测量传输速度
dd if=/dev/sda of=/dev/null bs=1M count=1000
```

### 调试工具

常用的调试命令：

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
