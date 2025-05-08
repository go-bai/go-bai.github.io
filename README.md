# README

## prerequisites

```bash
➜  ~ gcc --version
gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0
Copyright (C) 2021 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

➜  ~ go version
go version go1.23.1 linux/amd64
```

## init

```bash
make init
```

## add a new page

```bash
hugo new content posts/linux/jq-command.md
```

## preview

```bash
make server
```

## git push

```bash
make git-push
```

## 其他

### 自定义hugo `toc`的目录

https://gohugo.io/getting-started/configuration-markup/#table-of-contents
https://gohugo.io/content-management/toc/

```yaml
markup:
  tableOfContents:
    endLevel: 5
    ordered: false
    startLevel: 2
```

### 目录层级

最多两层, 层级多了不好找

### 文章顺序

1. 文章顺序按照 `date` 字段排序, 从晚到早
2. 如果 `date` 字段相同或不存在 `date` 字段, 按照 `title` 字段字典序排序
