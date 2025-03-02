### prerequisites

```bash
➜  ~ gcc --version
gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0
Copyright (C) 2021 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

➜  ~ go version
go version go1.23.1 linux/amd64
```

### install hugo extended

```bash
CGO_ENABLED=1 go install -tags extended github.com/gohugoio/hugo@latest
```

### pull theme submodule

```bash
git submodule update --init
```

### add a new page

```bash
hugo new content posts/linux/jq-command.md
```

### preview

```bash
hugo server --bind 0.0.0.0 --minify --theme hugo-book
```

### push

```bash
bash push.sh
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