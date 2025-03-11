---
title: "Go应用在容器中的时区"
date: 2023-02-18T16:12:01+08:00
---

## 容器中的时区问题

应用直接运行在服务器上需要设置服务器时区为东八区，现在很多应用都是部署在容器中了，同样也是要设置容器镜像的时区。

许多容器镜像默认时区为 `UTC` ([Coordinated Universal Time 协调世界时](https://zh.wikipedia.org/zh-hans/%E5%8D%8F%E8%B0%83%E4%B8%96%E7%95%8C%E6%97%B6))，比东八区慢八个小时，当程序涉及数据库写入操作或者日志记录等功能时就会有时间差。

常规解决方案一般两大类

1. build docker镜像时就把镜像内的时区设置为 `Asia/Shanghai`
2. 运行容器时把本地时区正常的主机的时区配置文件挂载到容器。

### 看一下 `Go` 是如何读取时区文件并设置 `time.Time` 的时区的

`Go` 源码 [src/time/zoneinfo_unix.go](https://github.com/golang/go/blob/master/src/time/zoneinfo_unix.go) 中代码和注释都很清晰👍

```golang
package time

import (
    "syscall"
)

// Many systems use /usr/share/zoneinfo, Solaris 2 has
// /usr/share/lib/zoneinfo, IRIX 6 has /usr/lib/locale/TZ,
// NixOS has /etc/zoneinfo.
var platformZoneSources = []string{
    "/usr/share/zoneinfo/",
    "/usr/share/lib/zoneinfo/",
    "/usr/lib/locale/TZ/",
    "/etc/zoneinfo",
}

func initLocal() {
    // consult $TZ to find the time zone to use.
    // no $TZ means use the system default /etc/localtime.
    // $TZ="" means use UTC.
    // $TZ="foo" or $TZ=":foo" if foo is an absolute path, then the file pointed
    // by foo will be used to initialize timezone; otherwise, file
    // /usr/share/zoneinfo/foo will be used.

    tz, ok := syscall.Getenv("TZ")
    switch {
    case !ok:
        z, err := loadLocation("localtime", []string{"/etc"})
        if err == nil {
            localLoc = *z
            localLoc.name = "Local"
            return
        }
    case tz != "":
        if tz[0] == ':' {
            tz = tz[1:]
        }
        if tz != "" && tz[0] == '/' {
            if z, err := loadLocation(tz, []string{""}); err == nil {
                localLoc = *z
                if tz == "/etc/localtime" {
                    localLoc.name = "Local"
                } else {
                    localLoc.name = tz
                }
                return
            }
        } else if tz != "" && tz != "UTC" {
            if z, err := loadLocation(tz, platformZoneSources); err == nil {
                localLoc = *z
                return
            }
        }
    }

    // Fall back to UTC.
    localLoc.name = "UTC"
}
```

首先检查是否设置了 `TZ` 环境变量

- 设置了 `TZ`
  - `TZ` 为空
    - 则时区还是 `UTC`
  - `TZ` 第一个字符为 `:`
    - 去掉 `:`
  - `TZ` 不为空且第一个字符为 `/`
    - 从 `TZ` 设置的路径中加载时区文件并设置时区
    - 如果没加载到时区文件，那么最终还是 `UTC` 时区。
  - `TZ` 不为空且不是 `UTC`
    - 从 `platformZoneSources` 中的几个路径下中加载 `TZ` 指定的时区文件并设置时区
    - 如果没加载到时区文件，那么最终还是 `UTC` 时区。
- 没设置 `TZ`
  - 加载 `/etc/localtime` 时区文件
  - 如果没加载到时区文件，那么最终还是 `UTC` 时区。

综上，在 `Dockerfile` 中可以用下面两种方式之一正确设置时区

1. 设置 `TZ` 为 `Asia/Shanghai`
2. 不设置 `TZ`，将 `/usr/share/zoneinfo/Asia/Shanghai` 拷贝或软链到 `/etc/localtime`

上面两种方式都需要有 `/usr/share/zoneinfo/Asia/Shanghai` 时区文件。
