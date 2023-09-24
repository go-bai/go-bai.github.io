### prerequisites

```bash
➜  ~ gcc --version
gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0
Copyright (C) 2021 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

➜  ~ go version
go version go1.21.1 linux/amd64
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
hugo new content post/linux/jq-command.md
```

### preview

```bash
hugo server
```

### push

```bash
bash push.sh
```