---
title: "Kubevirt Hook Sidecar"
date: 2024-05-12T14:37:18+08:00
---

## 简介

### 背景

> 在kubevirt中, 通过vmi的spec没办法涵盖所有的[libvirt domain xml](https://libvirt.org/formatdomain.html)元素, 所以有了hook sidecar功能来允许我们在define domain之前自定义domainSpecXML

### 功能介绍

在kubevirt中, Hook Sidecar容器是sidecar container(和main application container跑在同一个pod中)用来在vm初始化完成前执行一些自定义操作.

sidecar container与main container(compute)通过gRPC通讯, 有两种主要的sidecar hooks

1. `OnDefineDomain`: 这个hook帮助自定义libvirt的XML, 并通过gRPC协议返回最新的XML以创建vm
2. `PreCloudInitIso`: 这个hook帮助定义cloud-init配置, 它运行并返回最新的cloud-init data
3. `Shutdown`: 这个是`v1alpha3`版本才支持的

使用hook sidecar功能需要在`kv.spec.configuration.developerConfiguration.featureGates`中开启`Sidecar`功能

## 源码分析

### kubevirt-boot-sidecar 介绍

以下以[kubevirt-boot-sidecar](https://github.com/go-bai/kubevirt-boot-sidecar)为例讲述sidecar的工作流程, 这个sidecar支持修改`引导设备顺序(boot)`和`开启交互式引导菜单(bootmenu)`

`kubevirt-boot-sidecar`只实现了`OnDefineDomain`, 下面也是主要串一下OnDefineDomain相关的

### sidecar工作流程

1. `virt-launcher`刚启动时收集所有sidecar信息
    ```golang
    // cmd/virt-launcher/virt-launcher.go
    func main() {
        hookSidecars := pflag.Uint("hook-sidecars", 0, "Number of requested hook sidecars, virt-launcher will wait for all of them to become available")
        // 收集所有sidecar的信息
        err := hookManager.Collect(*hookSidecars, *qemuTimeout)

        // 启动 cmd server, 这里面有 SyncVirtualMachine 方法, 具体的实现在 func (l *LibvirtDomainManager) SyncVMI
        // virt-handler在初始化完虚拟机硬盘等之后会通过 SyncVirtualMachine 调用SyncVMI函数开始创建domain
        // SyncVMI将vmi spec转换为domainSpec, 然后调用hooksManager.OnDefineDomain执行所有的sidecar的OnDefineDomain方法
        // 最终用OnDefineDomain编辑后的domainSpec创建domain
        cmdServerDone := startCmdServer(cmdclient.UninitializedSocketOnGuest(), domainManager, stopChan, options)
    }

    // pkg/hooks/manager.go
    // numberOfRequestedHookSidecars为vmi注解 hooks.kubevirt.io/hookSidecars 的数组长度, 在virt-controller生成pod manifest的逻辑中计算得出
    func (m *hookManager) Collect(numberOfRequestedHookSidecars uint, timeout time.Duration) error {
        // callbacksPerHookPoint
        callbacksPerHookPoint, err := m.collectSideCarSockets(numberOfRequestedHookSidecars, timeout)
        m.CallbacksPerHookPoint = callbacksPerHookPoint
    }

    // pkg/hooks/manager.go
    func (m *hookManager) collectSideCarSockets(numberOfRequestedHookSidecars uint, timeout time.Duration) (map[string][]*callBackClient, error) {
        callbacksPerHookPoint := make(map[string][]*callBackClient)
        processedSockets := make(map[string]bool)
        timeoutCh := time.After(timeout)

        for uint(len(processedSockets)) < numberOfRequestedHookSidecars {
            sockets, err := os.ReadDir(m.hookSocketSharedDirectory)
            // 遍历 /var/run/kubevirt-hooks/ 目录下的 unix socket 文件
            for _, socket := range sockets {
                select {
                case <-timeoutCh:
                    return nil, fmt.Errorf("Failed to collect all expected sidecar hook sockets within given timeout")
                default:
                    if _, processed := processedSockets[socket.Name()]; processed {
                        continue
                    }

                    // 连接 sock 文件对应的 sidecar server 的 Info 函数获取 server 实现了哪些 hook(onDefineDomain或preCloudInitIso)
                    callBackClient, notReady, err := processSideCarSocket(filepath.Join(m.hookSocketSharedDirectory, socket.Name()))
                    if notReady {
                        log.Log.Info("Sidecar server might not be ready yet, retrying in the next iteration")
                        continue
                    } else if err != nil {
                        return nil, err
                    }

                    // callbacksPerHookPoint[onDefineDomain|preCloudInitIso][]*callBackClient{}
                    // 聚合出 onDefineDomain:["aaaa.sock","bbbb.sock"]
                    for _, subscribedHookPoint := range callBackClient.subscribedHookPoints {
                        callbacksPerHookPoint[subscribedHookPoint.GetName()] = append(callbacksPerHookPoint[subscribedHookPoint.GetName()], callBackClient)
                    }

                    processedSockets[socket.Name()] = true
                }
            }
            time.Sleep(time.Second)
        }
        // {"onDefineDomain":[{"SocketPath":"/var/run/kubevirt-hooks/shim-xxxx.sock", "Version":"v1alpha3", "subscribedHookPoints": [{"name": "onDefineDomain", "priority": 0}]}]}
        return callbacksPerHookPoint, nil
    }
    ```
2. `virt-launcher`启动之后, `virt-handler`会执行一些本地盘等相关初始化配置后通过gRPC调用`virt-launcher`的`SyncVirtualMachine`方法开始创建domain
    1. `SyncVMI`
        1. `Convert_v1_VirtualMachineInstance_To_api_Domain` 将 vmi 转换为 domainSpec
        2. `lookupOrCreateVirDomain` 先`LookupDomainByName`, 如果已存在则直接退出
            1. `preStartHook`
                ```golang
                hooksManager := hooks.GetManager()
                // 执行所有的 PreCloudInitIso sidecar
	            cloudInitData, err = hooksManager.PreCloudInitIso(vmi, cloudInitData)
                ```
            2. `setDomainSpecWithHooks`
                ```golang
                // pkg/virt-launcher/virtwarp/util/libvirt-helper.go
                func SetDomainSpecStrWithHooks(virConn cli.Connection, vmi *v1.VirtualMachineInstance, wantedSpec *api.DomainSpec) (cli.VirDomain, error) {
                    hooksManager := getHookManager()
                    // 执行所有的 OnDefineDomain sidecar
	                domainSpec, err := hooksManager.OnDefineDomain(wantedSpec, vmi)
                    // 调用 virConn.DomainDefineXML 创建 domain
                    return SetDomainSpecStr(virConn, vmi, domainSpec)
                }

                // /pkg/hooks/manager.go
                func (m *hookManager) OnDefineDomain(domainSpec *virtwrapApi.DomainSpec, vmi *v1.VirtualMachineInstance) (string, error) {
                    domainSpecXML, err := xml.MarshalIndent(domainSpec, "", "\t")

                    callbacks, found := m.CallbacksPerHookPoint[hooksInfo.OnDefineDomainHookPointName]
                    if !found {
                        return string(domainSpecXML), nil
                    }

                    vmiJSON, err := json.Marshal(vmi)

                    for _, callback := range callbacks {
                        // 执行所有的sidecar OnDefineDomain函数, 一次次编辑domainSpecXML
                        domainSpecXML, err = m.onDefineDomainCallback(callback, domainSpecXML, vmiJSON)
                    }

                    return string(domainSpecXML), nil
                }

                // /pkg/hooks/manager.go
                func (m *hookManager) onDefineDomainCallback(callback *callBackClient, domainSpecXML, vmiJSON []byte) ([]byte, error) {
                    // dial /var/run/kubevirt-hooks/shim-xxxx.sock
                    conn, err := grpcutil.DialSocketWithTimeout(callback.SocketPath, 1)

                    switch callback.Version {
                    case hooksV1alpha3.Version:
                        client := hooksV1alpha3.NewCallbacksClient(conn)
                        // 调用sidecar server 的 OnDefineDomain 方法
                        result, err := client.OnDefineDomain(ctx, &hooksV1alpha3.OnDefineDomainParams{
                            DomainXML: domainSpecXML,
                            Vmi:       vmiJSON,
                        })
                        domainSpecXML = result.GetDomainXML()
                    }

                    return domainSpecXML, nil
                }
                ```

会发现上面主要是sidecar client视角, 没有介绍sidecar server在哪实现的, 最新的解决方案是搭配`sidecar-shim`, 下面开始介绍

### sidecar-shim介绍

为了简化sidecar的开发, kubevirt提供了[sidecar-shim](https://github.com/kubevirt/kubevirt/blob/main/cmd/sidecars/sidecar_shim.go)镜像完成和主容器的通信, 我们只需要开发一个程序接收`vmi`和`domain`两个参数, 然后编译成名为`onDefineDomain`的可执行程序放到sidecar-shim镜像的`/usr/bin/`目录即可, sidecar-shim在执行时会执行我们开发的可执行程序.
```go
// /cmd/sidecars/sidecar_shim.go
func runOnDefineDomain(vmiJSON []byte, domainXML []byte) ([]byte, error) {
    // 检查是否存在 onDefineDomainBin 可执行程序
    if _, err := exec.LookPath(onDefineDomainBin); err != nil {
        return nil, fmt.Errorf("Failed in finding %s in $PATH due %v", onDefineDomainBin, err)
    }

    vmiSpec := virtv1.VirtualMachineInstance{}
    if err := json.Unmarshal(vmiJSON, &vmiSpec); err != nil {
        return nil, fmt.Errorf("Failed to unmarshal given VMI spec: %s due %v", vmiJSON, err)
    }

    args := append([]string{},
        "--vmi", string(vmiJSON),
        "--domain", string(domainXML))

    command := exec.Command(onDefineDomainBin, args...)
    // 只有将开发的可执行程序错误日志写入到stderr中才会在hook-sidecar-x容器日志中打印出来
    // stdout只用来输出新的domainSpecXML, 如果程序exit code非0, 则不会打印stdout中的内容
    if reader, err := command.StderrPipe(); err != nil {
        log.Log.Reason(err).Infof("Could not pipe stderr")
    } else {
        go logStderr(reader, "onDefineDomain")
    }
    // command.Output()返回的error信息只有exit code
    return command.Output()
}
```

`virt-launcher` pod内所有容器共享 `/var/run/kubevirt-hooks`目录, `sidecar-shim`在`/var/run/kubevirt-hooks`目录下创建sock文件实现Info和OnDefineDomain方法然后监听gRPC远程调用, 然后主容器会连接`/var/run/kubevirt-hooks`目录下的sock文件调用函数

### 使用 kubevirt-boot-sidecar

只需在vmi的模版中增加两个注解
- `hooks.kubevirt.io/hookSidecars`会被`virt-controller`读取并生成virt-launcher 的 pod manifest时增加一个hook-sidecar-x的容器
- `os.vm.kubevirt.io/boot`会被`ghcr.io/go-bai/kubevirt-boot-sidecar`镜像中的`/usr/bin/onDefineDomain`程序读取并用来设置在domainSpecXML中返回给`virt-launcher`, 最终用来define domain

```diff
apiVersion: kubevirt.io/v1
kind: VirtualMachine
spec:
  template:
    metadata:
      annotations:
+       hooks.kubevirt.io/hookSidecars: '[{"args": ["--version", "v1alpha3"],"image": "ghcr.io/go-bai/kubevirt-boot-sidecar:v1.2.0"}]'
+       os.vm.kubevirt.io/boot: '{"boot":[{"dev":"hd"},{"dev":"cdrom"}]}'
```

## 注意点

- `OnDefineDomain`可能会被[调用超过一次](https://github.com/kubevirt/kubevirt/pull/11324#issuecomment-1963766377), 所以要保证函数幂等 

## 参考
- [[offical user guide] hook-sidecar](https://kubevirt.io/user-guide/operations/hook-sidecar/)

