---
title: "Shell Script"
date: 2024-03-23T09:43:34+08:00
draft: false
toc: true
tags: [shell,bash,linux]
---

最近写的shell脚本比较多，记录一些经典场景下的写法

## `#!/bin/bash`

shell是

而`#!/bin/bash`表示在直接执行此脚本文件时使用`/bin/bash`做为shell解释器程序

很多主流操作系统默认的shell解释器也是bash

```bash
# echo $SHELL
/bin/bash
```

### set

```bash
#!/bin/bash

set -
```
