---
title: "Shell Script"
date: 2024-03-23T09:43:34+08:00
draft: false
toc: true
tags: [shell,bash,linux]
---

最近写的shell脚本比较多，记录一些常用命令

## `#!/bin/bash`

`#!/bin/bash`表示在直接执行此脚本文件时使用`/bin/bash`做为shell解释器程序

很多主流操作系统默认的shell解释器也是bash

```bash
# echo $SHELL
/bin/bash
```

## `set`

`set`命令用来修改shell环境的运行参数, 完整的可定制的[官方手册](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)

下面是我常用的几个, 可以合并为如下内容写在脚本开头:

```bash
#!/bin/bash
set -uxe
set -o pipefail
```

### `set -u`

执行脚本时, 如果遇到不存在的变量, Bash默认会忽略, `set -u`可以让脚本读到不存在变量时报错

### `set -x`

命令执行前会先打印出来, 行首以`+`表示, 在调试脚本时非常有帮助

### `set -e`

执行脚本时, Bash遇到错误默认会继续执行, `set -e`使得脚本只要发生错误, 就中止执行

### `set -o pipefail`

`set -e`有一个例外情况, 就是不适用于管道命令, 比如下面的不会退出

```bash
#!/bin/bash
set -e

foo | echo a
echo bar
```

执行的结果为:

```bash
a
set.sh: line 4: foo: command not found
bar
```

`set -o pipefail`可以解决这个问题, 只要一个子命令失败, 整个管道命令就失败, 脚本就会终止执行

```bash
#!/bin/bash
set -eo pipefail

foo | echo a
echo bar
```

执行的结果为:

```bash
a
set.sh: line 4: foo: command not found
```

## `sed`

TODO

### 替换文件中的字符串

```bash
sed -
```

### 替换文件中以xxx开头的后面的内容


## `cat <<EOF`

`cat`一般用来查看文件内容, `cat <<EOF`可以用来将多行内容写入到文件里.

### 写入到文件

这里的`\$PWD`写入到脚本后将会是`$PWD`, `$PWD`将会解析为当前执行路径.

```bash
cat <<EOF > print.sh
#!/bin/bash
echo \$PWD
echo "$PWD"
EOF
```