---
title: "sqlite3 笔记"
date: 2021-12-14T10:33:14+08:00
draft: false
tags: ["sqlite3"]
---


## rollback日志模式下的五种锁状态介绍

- `UNLOCKED`
    - 没锁状态
- `SHARED`
    - 获取`SHARED`锁才能执行读操作，一个数据库可同时存在多个`SHARED`锁
- `RESERVED`
    - 获取`RESERVED`锁才能在未来写数据库，一个数据库同一时间只能存在一个`RESERVED`锁
    - 有`RESERVED`锁时说明还没开始写，所以有`RESERVED`锁时可以获取新的`SHARED`锁
- `PENDING`
    - 有`PENDING`锁意味着要开始写了，但是此时有其他连接拥有`SHARED`锁在读数据，此时写操作只能等待所有`SHARED`释放。
    - `PENDING`阻塞其他连接获取新的`SHARED`锁，当`SHARED`锁释放完时转为`EXCLUSIVE`锁开始写操作。
- `EXCLUSIVE`
    - 同一时间只能存在一个`EXCLUSIVE`锁，并且有`EXCLUSIVE`锁存在时不允许其他任何锁类型存在。

所以总结一下就是读读可并发，读写不可并发，写写不可并发。

## 优化篇

### `SQLITE_BUSY` 问题

看到上面这么多锁不能共存的情况应该会想到，冲突会很频繁，如 `EXCLUSIVE` 锁存在时不允许其他连接获取任何锁，当其他进程需要读写操作时就会获取锁失败，立即报 `SQLITE_BUSY` 错误。

设置 `busy_timeout` 就不会立即返回 `SQLITE_BUSY`，会定时retry失败的操作，如果在设置的 `busy_timeout` 时间内还没执行成功，依然会返回 `SQLITE_BUSY`。

使用不同sqlite驱动，设置 `busy_timeout` 的方式不同

- modernc.org/sqlite `database.db?_pragma=busy_timeout%3d50000`
- github.com/mattn/go-sqlite3 `database.db?_busy_timeout=50000`

Shared cache mode 支持 table level locks，暂时还没研究。

### 针对写操作慢的问题

解决方案：将多个写操作放入一个事务里执行。sqlite官方[FAQ](https://www.sqlite.org/faq.html#q19)对其解释如下

> (19) INSERT is really slow - I can only do few dozen INSERTs per second
Actually, SQLite will easily do 50,000 or more INSERT statements per second on an average desktop computer. But it will only do a few dozen transactions per second. Transaction speed is limited by the rotational speed of your disk drive. A transaction normally requires two complete rotations of the disk platter, which on a 7200RPM disk drive limits you to about 60 transactions per second.
Transaction speed is limited by disk drive speed because (by default) SQLite actually waits until the data really is safely stored on the disk surface before the transaction is complete. That way, if you suddenly lose power or if your OS crashes, your data is still safe. For details, read about [atomic commit in SQLite..](https://www.sqlite.org/atomiccommit.html)
By default, each INSERT statement is its own transaction. But if you surround multiple INSERT statements with BEGIN...COMMIT then all the inserts are grouped into a single transaction. The time needed to commit the transaction is amortized over all the enclosed insert statements and so the time per insert statement is greatly reduced.
Another option is to run PRAGMA synchronous=OFF. This command will cause SQLite to not wait on data to reach the disk surface, which will make write operations appear to be much faster. But if you lose power in the middle of a transaction, your database file might go corrupt.

测试环境

```bash
# 表信息
sqlite> select count(*) from users;
1553471

# 日志模式
sqlite> PRAGMA journal_mode;
delete
```

10次 insert 不在一个事务里

```bash
$ go test -bench="^Bench" -benchtime=5s .
goos: linux
goarch: amd64
pkg: gocn/sqlite-test
cpu: Intel(R) Xeon(R) Silver 4214 CPU @ 2.20GHz
BenchmarkWrite-8              52         128920972 ns/op
BenchmarkRead-8           141531             43400 ns/op
BenchmarkWriteCGO-8           63          81576398 ns/op
BenchmarkReadCGO-8        644850              8446 ns/op
PASS
ok      gocn/sqlite-test        29.049s

# 结果解释
# write 和 read 单次执行内容分别是十条 inster 和一条 select
# BenchmarkWrite 是使用 modernc.org/sqlite 驱动的写操作
# BenchmarkWriteCGO 是使用 github.com/mattn/go-sqlite3 驱动的写操作
```

10次 insert 在一个事务里后

```bash
$ go test -bench="^Bench" -benchtime=5s .
goos: linux
goarch: amd64
pkg: gocn/sqlite-test
cpu: Intel(R) Xeon(R) Silver 4214 CPU @ 2.20GHz
BenchmarkWrite-8             601          12099375 ns/op
BenchmarkRead-8           142848             43089 ns/op
BenchmarkWriteCGO-8          912           8050617 ns/op
BenchmarkReadCGO-8        720722              8244 ns/op
PASS
ok      gocn/sqlite-test        38.372s
```

可以看出来，写操作性能提升明显，写的单次操作(十次insert)时间直接下降了一个数量级，如果能将更多写操作放入一个事务里，性能提升也会越多，直至达到sqlite的写操作瓶颈(50,000 or more INSERT statements per second)。


参考文档

- [官方文档-五种锁状态介绍](https://www.sqlite.org/lockingv3.html)
- [官方FAQ](https://www.sqlite.org/faq.html#q19)
- [Understanding SQLITE_BUSY](https://activesphere.com/blog/2018/12/24/understanding-sqlite-busy#fn:1)
- [github.com/mattn/go-sqlite3](https://github.com/mattn/go-sqlite3/blob/3392062c729d77820afc1f5cae3427f0de39e954/sqlite3.go#L919)
- [modernc.org/sqlite](https://gitlab.com/cznic/sqlite/-/commit/e3be4b029c0e128faa7bfb5e06f67c8fda33db4a#bb99b1baec3b0c8f02dc4e87b04926bc377fd8db_803_802)