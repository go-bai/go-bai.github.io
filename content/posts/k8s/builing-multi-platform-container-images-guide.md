---
title: "构建多平台容器镜像"
date: 2024-10-13T11:27:56+08:00
draft: false
---

> 构建多平台容器镜像

## Docker buildx 插件/子命令

[buildx](https://github.com/docker/buildx) 是 Docker 的一个 CLI 插件，用于扩展来自于 [Moby BuildKit](https://github.com/moby/buildkit) 项目的构建功能。

注意：buildx 需要 Docker 19.03 或更高版本。

## BuildKit

BuildKit是一个build引擎，它接收一个配置文件（Dockerfile），并转化成一个制品（容器镜像或其他制品）。相较与传统的build具有多阶段并发构建、更好的layer缓存支持等优点，Dockerfile中的RUN指令会被runc执行。

Docker Engine 从 [23.0.0](https://docs.docker.com/engine/release-notes/23.0/#2300) 版本开始默认在Linux上使用Buildx和BuildKit为builder。

### Builder: a BuildKit daemon

- [Builders介绍](https://docs.docker.com/build/builders/)

一个 builder 是一个 BuildKit 守护进程，BuildKit是build引擎，它解决Dockerfile中的构建步骤，以生成容器镜像或其他制品。

### Build drivers

Build 驱动有多种，例如 `docker`、`docker-container`、`kubernetes`、`remote` 等。

- `docker` 使用捆绑在Docker守护进程中的BuildKit库。默认的Builder使用的该驱动。
- `docker-container` 使用Docker创建一个专用的BuildKit容器。
- `kubernetes` 在Kubernetes集群中创建BuildKit pods。
- `remote` 直接连接到手动管理的BuildKit守护进程。

<div style="text-align: center;">Build Drivers Comparison</div>

| Feature                     | docker | docker-container | kubernetes | remote |
|-----------------------------|--------|------------------|------------|--------|
| Automatically load image     | ✅     |                  |            |        |
| Cache export                 | ✓*     | ✅               | ✅         | ✅     |
| Tarball output               |        | ✅               | ✅         | ✅     |
| Multi-arch images            |        | ✅               | ✅         | ✅     |
| BuildKit configuration       |        | ✅               |            | Managed externally |

<div style="text-align: center;">* The docker driver doesn't support all cache export options</div>

### 默认的 Builder 实例

docker engine 会自动创建一个默认的 builder 实例，例如 `default`。默认的驱动是 `docker`，不支持多平台构建。

```bash
# docker buildx ls
NAME/NODE     DRIVER/ENDPOINT   STATUS    BUILDKIT   PLATFORMS
default*      docker                                 
 \_ default    \_ default       running   v0.16.0    linux/amd64, linux/amd64/v2, linux/amd64/v3, linux/386
```

### 创建 Builder 实例

下面创建一个 `docker-container` driver 的 builder 实例。

```bash
docker buildx create \
  --name container-builder \
  --driver docker-container \
  --platform linux/amd64,linux/arm64 \
  --bootstrap \
  --use
```

参数介绍:

- `--name` 指定实例名称
- `--driver` 指定驱动，默认是 `docker`，`docker`不支持多平台构建，这里使用支持多平台构建的 `docker-container`
- `--platform` 指定支持的平台
- `--bootstrap` 启动实例
- `--use` 指定使用该实例

创建后会发现多了一个容器 `buildx_buildkit_container-builder0`, 使用的镜像是 `moby/buildkit:buildx-stable-1`。

```bash
# docker ps
CONTAINER ID   IMAGE                           COMMAND                  CREATED          STATUS          PORTS   NAMES
6be2b567eaa3   moby/buildkit:buildx-stable-1   "buildkitd --allow-i…"   31 minutes ago   Up 31 minutes           buildx_buildkit_container-builder0
```

可以指定builder实例容器使用的容器镜像，`--driver-opt image=name`

可以指定buildkitd配置文件路径，`--buildkitd-config /path/to/buildkitd.toml`

buildkitd 可以配置镜像仓库的insecure等配置，参考[buildkitd config](https://github.com/moby/buildkit/blob/master/docs/buildkitd.toml.md)，demo如下

```toml
# buildkitd.toml
[registry."registry.example.com"]
insecure = true
http = true
```

## 使用 buildx 构建多平台镜像

Buildx + Dockerfile 构建多平台镜像有[三种方式](https://github.com/docker/buildx?tab=readme-ov-file#building-multi-platform-images)

1. 在内核中使用QEMU仿真支持, 利用的内核的 binfmt_misc 机制提供运行多平台二进制文件的能力
    - `docker run --privileged --rm tonistiigi/binfmt --install all` 注册所有平台的二进制文件格式到内核中
    - 上面的命令会将所有平台的二进制文件格式注册到内核中，例如 `linux/arm64`、`linux/amd64` 等, 可以在 `/proc/sys/fs/binfmt_misc/qemu-*` 看到注册的二进制文件格式和对应的解释器路径
2. 使用相同的构建器实例在多个不同平台节点上构建
3. 使用Dockerfile中的一个阶段来交叉编译到不同的架构，需要语言支持交叉编译(Go语言等)或者平台无关(Java语言和前端静态文件等)

下面是使用 BuildKit 构建多平台镜像时，Dockerfile 中可以使用的ARGs, 参考[Automatic platform args in the global scope](https://docs.docker.com/reference/dockerfile/#automatic-platform-args-in-the-global-scope)

- `BUILDPLATFORM` 是构建时平台的标识符，例如 `linux/amd64`
- `BUILDOS` 是构建时操作系统的标识符，例如 `linux`
- `BUILDARCH` 是构建时架构的标识符，例如 `amd64`
- `TARGETPLATFORM` 是目标平台的标识符，例如 `linux/arm64`
- `TARGETOS` 是目标操作系统的标识符，例如 `linux`
- `TARGETARCH` 是目标架构的标识符，例如 `arm64`

使用第一种多平台镜像构建方式是最简单的（如果构建使用的节点支持），下面这个实例使用第三种构建多平台镜像方式，在 Dockerfile 中使用一个阶段来交叉编译到不同的架构。

```bash
# Dockerfile
# 第一个阶段, 使用构建时所在平台的镜像环境中交叉编译, 最终复制到目标平台对应的镜像中使用
FROM --platform=$BUILDPLATFORM golang:1.23.1-alpine AS builder
ARG TARGETOS
ARG TARGETARCH
ENV GO111MODULE=on \
    CGO_ENABLED=0
WORKDIR /build
RUN apk --no-cache add tzdata
COPY . .
# 交叉编译
# docker buildx build --platform linux/amd64,linux/arm64 ... 等同于在 linux/amd64 平台下执行
# 1. GOOS=linux GOARCH=amd64 go build -ldflags "-s -w" -o main
# 2. GOOS=linux GOARCH=arm64 go build -ldflags "-s -w" -o main
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags "-s -w" -o main

# 第二个阶段, 使用目标平台的镜像做为运行时镜像
# FROM 默认 --platform=$TARGETPLATFORM
FROM scratch
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /build/main /

ENTRYPOINT ["/main"]
```

### 构建镜像

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t registry.example.com/my-image:latest .
```

### 推送镜像

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t registry.example.com/my-image:latest --push .
```

## 参考

- [(docker docs) Multi-platform builds](https://docs.docker.com/build/building/multi-platform/)
