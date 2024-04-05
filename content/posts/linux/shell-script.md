---
title: "Shell Script"
date: 2024-03-23T09:43:34+08:00
draft: false
toc: true
tags: [shell,bash,linux]
---

> 最近写的shell脚本比较多，记录一些常用命令, 相当于记录一个索引, 以后用时可以快速回忆起来.

## `#!/bin/bash`

`#!/bin/bash`被称为`shebang line`, 指定执行此脚本文件时使用`/bin/bash`做为shell解释器程序

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

## 单引号`''`和双引号`""`

双引号会将`$var`解析成本身的值, 单引号不会解析

```bash
# var=1
# echo "$var"
1
# echo '$var'
$var
```

## `<<` here document

一般使用`Here Document`作为标准输入喂给`kubectl apply -f -`或者重定向到文件里.

```bash
#!/bin/bash

# 标识符或限定符IDENT一般使用EOF表示
COMMAND <<IDENT
this is ...
IDENT
```

### `cat <<EOF`写入到文件

`cat`一般用来查看文件内容, `cat <<EOF`可以用来将多行内容打印到标准输出重定向写入到文件里, 这里`限定符`使用`EOF`.

```bash
cat <<EOF > doc.md
# this is ...
EOF
```

### `kubectl apply -f - <<EOF`

使用`kubectl`直接不创建文件去`apply`一个yaml

```bash
kubectl apply -f - <<EOF
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: macvlan-conf-2
EOF
```

## `sed` (stream editor)

`sed`全名`stream editor`, 会流式的一行一行编辑文件, [sed手册](https://www.gnu.org/software/sed/manual/sed.html)

下面的修改都是打印到标准输出, 加上`-i`参数`sed -i 'xxx' filename`就可以直接更新到文件了

### `s`命令替换字符串

结合上面的`here document`一起演示, 这样就不用再单独创建文件了

#### 将镜像tag`latest`改为`v1.1.1`

```bash
sed 's/latest/v1.1.1/g' - <<EOF
ecr.gobai.top/example:latest
EOF
```

> `s`表示替换命令, `/latest/`表示匹配`latest`, `/v1.1.1/`表示将匹配到的替换为`v1.1.1`, `/g`表示每一行中匹配到的全部替换, 没有`g`只会替换每一行中的第一个.

#### 只替换行中匹配到的某一个

```bash
# 替换第1个
sed 's/latest/v1.1.1/1' - <<EOF
ecr.gobai.top/example:latest latest latest
EOF

# 替换第2个
sed 's/latest/v1.1.1/2' - <<EOF
ecr.gobai.top/example:latest latest latest
EOF

# 替换第2个和之后的
sed 's/latest/v1.1.1/2g' - <<EOF
ecr.gobai.top/example:latest latest latest
EOF
```

#### 只替换部分行字符串

```bash
# 只替换第2行
sed '2s/latest/v1.1.1/g' - <<EOF
ecr.gobai.top/example:latest
ecr.gobai.top/example:latest
ecr.gobai.top/example:latest
EOF

# 只替换2-3行
sed '2,3s/latest/v1.1.1/g' - <<EOF
ecr.gobai.top/example:latest
ecr.gobai.top/example:latest
ecr.gobai.top/example:latest
EOF
```

> 更复杂的涉及很多正则的场景我一般直接丢给`ChatGPT`去写, 知道`sed`可以完成这些任务就可以了!!!

### 一些`sed`中常用的正则的语法

大部分都是通用的, 在其他需要正则匹配的地方也可以使用, 如在`grep -e`或`grep -E`中也可以使用

https://www.gnu.org/software/sed/manual/html_node/Regular-Expressions.html

|字符|含义|
|:--|:--|
||单个普通字符匹配自身|
|`*`|匹配`*`前面正则表达式的零个或多个匹配项|
|`\+`|类似`*`, 但是匹配至少一个|
|`\?`|类似`*`, 但是匹配零个或一个|
|`\{i\}`|类似`*`, 但是匹配`i`个|
|`\{i,\}`|类似`*`, 匹配至少`i`个|
|`\(regexp\)`|将内部的`regexp`作为一个整体分组|
|`.`|匹配任意单个字符, 包括换行|
|`^`|匹配开始处的`null`字符串|
|`$`|匹配结尾处的`null`字符串|
|`[list]`|匹配方括号中的字符列表中的任意一个|
|`[^list]`|匹配`非`方括号中的字符列表中的任意一个|
|`regexp1\|regexp2`|匹配`regexp1`或`regexp2`|
|`regexp1regexp2`|匹配`regexp1`和`regexp2`的连接结果|
|`\digit`|匹配正则表达式中第`digit`个圆括号`\(...\)`子表达式|
|`\n`|匹配换行符|
|`\char`|匹配`char`字符, `char`可以是`$` `*` `.` `[` `\` 或者 `^`|


一些注意点:

1. 虽然`.`可以匹配换行符, 但是有的命令是一行一行处理, 所以正则匹配不到换行, 如`sed`命令

### 圆括号匹配

圆括号括起来的正则表达式所匹配的字符串可以当成变量来使用, 通过`\1`或`\2`来引用

#### 将`VERSION`后面的版本替换

```bash
V="1.1.1"
sed "s/\(^VERSION:\s*\)[0-9.]\+/\1$V/" - <<EOF
VERSION: 0.0.1
EOF
```

> 圆括号`()`需要转义`\(\)`, 并且因为有变量`$V`, 单引号需要改为双引号, `^`代表行的开始, `VERSION:`匹配文本字符串, `\s*`匹配0或多个空白字符, 
`[0-9.]\+`匹配一个或多个数字或`.`, `\(^VERSION:\s*\)`匹配到了版本号前面的内容作为变量`1`, `\1$V`代表将匹配到的所有内容替换为版本好前面的内容+新的版本号`$V`

## `echo`命令

### `echo -n`

```bash
-n     do not output the trailing newline
```

在结尾处不自动添加换行符

### `echo -e`和`echo -E`

```bash
-e     enable interpretation of backslash escapes # 激活转义字符
-E     disable interpretation of backslash escapes (default)
```

## `grep`命令

`grep`应该是特别常见的命令了, `grep`支持从标准输入`stdin`作为参数, 如`echo 'abc' | grep abc`, 也可以从命令行输入参数, 如`grep abc demo.md`

### `grep -E`

正则匹配

```bash
# str=$(echo '1. aaa\n2. bbb')
# echo $str | grep -E 'a|b'
1. aaa
2. bbb
```

### `grep -i`

忽略大小写

```bash
# str=$(echo '1. aaa\n2. bbb')
# echo $str | grep -i -E 'A|B'
1. aaa
2. bbb
```

### `grep -v`

```bash
-v, --invert-match # 反向匹配, 选择不匹配的行
    Invert the sense of matching, to select non-matching lines.
```

获取不包含`a`的行

```bash
# str=$(echo '1. aaa\n2. bbb')
# echo $str | grep -v a    
2. bbb
```

### `grep -n`

```bash
-n, --line-number # 打印匹配到的行在输入中的行号
    Prefix each line of output with the 1-based line number within its input file.
```

打印匹配到的行的行号

```bash
# echo $str | grep -n -E 'a|b'
1:1. aaa
2:2. bbb
```

### `grep -r`

```bash
-r, --recursive # 递归读取目录下的文件
    Read all files under each directory, recursively, following symbolic links only if they are on the command line.  Note that if no file operand is
    given, B<grep> searches the working directory.  This is equivalent to the -d recurse option.
```

#### 在当前目录递归遍历匹配字符串并打印行号

```bash
grep -rn "string" .
```

## `xargs`命令

TODO

## `awk`命令

`awk`也是依次处理文件的每一行, 适合处理每一行格式相同的数据

基本用法

```bash
# 格式
awk 动作 文件名

# 示例
awk '{print $0}' - <<EOF
abc 123 666
bcd 234 777
EOF
```

> 大括号`{}`内部是处理当前行的动作, `$0`代表当前行, 最终效果就是原样打印所有行.
`awk`会根据`空格`或`制表符`将每一行分成若干字段, 通过`$1` `$2` `$3`代表每一个字段, 也可以通过`awk -F ':' '{print $1}' xxx`手动指定每一列之间的分隔符为`:`

## `ldd`命令

`ldd`可以查看一个可执行文件依赖哪些动态链接库

### 离线有动态链接库的程序

查看`jq`命令依赖哪些动态链接库, 

```bash
# ldd $(which jq)
        linux-vdso.so.1 (0x00007fff12b9f000)
        libjq.so.1 => /lib/x86_64-linux-gnu/libjq.so.1 (0x00007fc42d080000)
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007fc42ce00000)
        libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007fc42cd19000)
        libonig.so.5 => /lib/x86_64-linux-gnu/libonig.so.5 (0x00007fc42cc86000)
        /lib64/ld-linux-x86-64.so.2 (0x00007fc42d0e9000)
```

如果要离线一个脚本, 只需要将`=>`后面的文件复制一份打包即可, 这时`awk`命令就能派上用场了

```bash
APP_NAME="jq"
mkdir ${APP_NAME}_archive && cd ${APP_NAME}_archive
mkdir libs
ldd $(which ${APP_NAME}) | awk '{print $3}' | xargs -i cp -L {} libs
```

这样只需要再把可执行文件也离线, 就可以离线安装运行了

不过还有最后一步, 这些lib文件不适合直接都放入`/lib/`目录下?, 因为有可能这些lib目录下有和当前程序冲突的版本, 所以直接把程序依赖的lib放在一个目录下然后启动时设置`LD_LIBRARY_PATH`目录让程序去找正确版本的lib库是更稳妥的.

```bash
cp $(which ${APP_NAME}) .
cat <<EOF > app_${APP_NAME}.sh
#!/bin/bash
INSTALL_DIR="/opt/app_archives"
APP_NAME="${APP_NAME}"
export LD_LIBRARY_PATH="\${INSTALL_DIR}/\${APP_NAME}_archive/libs"
\${INSTALL_DIR}/\${APP_NAME}_archive/\${APP_NAME}  "\$@"
EOF
chmod +x app_${APP_NAME}.sh
```

最终的文件如下

```bash
# tree .                     
.
├── app_jq.sh
├── jq
└── libs
    ├── libc.so.6
    ├── libjq.so.1
    ├── libm.so.6
    └── libonig.so.5

1 directory, 6 files
```

安装时, 只需要将`${APP_NAME}_archive`目录放在`/opt/app_archives`目录下, 然后创建一个如下的软链即可

```bash
ln -nsf /opt/app_archives/\${APP_NAME}_archive/app_\${APP_NAME}.sh /usr/bin/\${APP_NAME}
```

## `mc`(minio client)

### 设置alias

```bash
mc alias set {NAME} http://minio.lan:9000 {USER} {PASSWORD}
```

### 设置匿名用户对某bucket权限

权限有`download`, `upload` 和 `public(download+upload)`

设置匿名用户可以下载某个bucket下的文件

```bash
# mc anonymous set download minio/app
Access permission for `minio/app` is set to `download`
```

查看匿名用户对某bucket的权限

```bash
# mc anonymous get minio/app
Access permission for `minio/app` is `download`
```

## `jq`命令

> `jq`用来处理json数据还是超级强大的

### `select`过滤数组

下面的命令用到了`jq`中的管道操作`|`和过滤操作`select`

```bash
# echo '[{"name":"compute","image":"c-image"},{"name":"log"}]' | jq '.[] | select(.name == "compute") | .image'
"c-image"
```

有时不想要字符串两边的双引号, 这时就需要用到上面用到的`sed`命令了, 思路是正则匹配整个字符串, 然后双引号中间的使用圆括号匹配作为变量`\1`, 最后将整个字符串替换为`\1`即可

```bash
# str=$(echo '[{"name":"compute","image":"c-image"},{"name":"log"}]' | jq '.[] | select(.name == "compute") | .image')
# echo $str | sed 's/^"\(.*\)"$/\1/'
c-image
```

## 参考

- [awk](https://www.ruanyifeng.com/blog/2018/11/awk.html)