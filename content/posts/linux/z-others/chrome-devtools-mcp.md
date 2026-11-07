---
title: "chrome-devtools-mcp 折腾记：别让每个 Claude 会话都起一个 Chrome"
date: 2026-10-17T22:00:00+08:00
lastmod: 2026-11-07T10:30:00+08:00
---

> 环境：Ubuntu 22.04 + GNOME 42 (X11) + Chrome 149 + chrome-devtools-mcp 1.2.0

用 Claude Code 的 `chrome-devtools` 插件做网页调试，发现一个很蠢的问题：**每开一个 Claude 会话就多一个 Chrome 进程**，而且是个带 `--headless --isolated` 的临时 Chrome，登录态全空，用完 profile 就删。

这篇记录一下原因和最终方案：用一个独立的调试专用 Chrome（非默认 profile + 固定调试端口），所有 MCP 会话用 `--browserUrl` 挂上去，不启动任何额外 Chrome。

> **2026-11 更新**：用了三周后发现内存大头不是 Chrome 而是 MCP 进程，真正贵的是 token。浏览器操作已经改成隔离子代理 + agent-browser CLI，见文末[更新](#2026-11-更新省下来的是内存烧掉的是-token)。

## 现象

`ps` 里能看到一串：

```
npm exec chrome-devtools-mcp@1.2.0 --headless --isolated --chrome-arg=--no-sandbox --chrome-arg=--disable-gpu
  └─ sh -c ...
       └─ node .../chrome-devtools-mcp/build/src/index.js
            └─ /opt/google/chrome/chrome --headless --user-data-dir=/tmp/chrome-profile-xxx ...
```

几个会话就是几组，内存蹭蹭涨。而且因为是隔离 profile，**每次都要重新登录**。

## 原因：插件把参数写死了

插件的 `plugin.json` 里固定了：

```json
"mcpServers": {
  "chrome-devtools": {
    "command": "npx",
    "args": ["chrome-devtools-mcp@1.2.0", "--headless", "--isolated",
             "--chrome-arg=--no-sandbox", "--chrome-arg=--disable-gpu"]
  }
}
```

- `--isolated`：每个 MCP server 起一个临时 profile，关掉就删 → 登录态不可能保留
- `--headless`：无窗口，也看不到登录流程

只要给 MCP 指定一个**已存在的可调试 Chrome**，它就走 `puppeteer.connect()`，根本不会 launch 浏览器。

## 坑一：Chrome 136+ 不允许对默认目录开调试端口

想直接给日常那个 Chrome 加 `--remote-debugging-port=9222` 是不行的。Chrome 136 起做了安全收紧，官方博客写得很直白：

> These switches will no longer be respected if attempting to debug the default Chrome data directory.

也就是说 `~/.config/google-chrome`（默认 user-data-dir）上开 `--remote-debugging-port` 会被**静默忽略**。这也是很多爬虫/自动化工具在 Chrome 136 之后突然连不上的原因。绕不过去，也不建议绕（绕过就意味着本机任何进程都能读你全部 cookie）。

## 坑二：chrome://inspect 的 Allow 弹窗不能记住

Chrome 144+ 提供另一个入口：`chrome://inspect/#remote-debugging` 手动打开调试。它会：

- 只暴露 WebSocket 端点，`/json/version` 和 `/json/list` 返回 **404**（所以 `--browserUrl` 根本连不上）
- 每建立一条 WebSocket 连接就弹一次 "Allow remote debugging?" —— 多开会话就多点几次
- 请求持久化授权在 upstream 被关掉了（closed as not planned）

而且这个模式本身也没解决"登录态共享"，只是能连上而已，直接放弃。

顺带一提：puppeteer 连这个端点失败时会报 `Could not find DevToolsActivePort`，**这是个误导性错误**。实际是 WebSocket 返回 403 被 `catch` 包了一层，跟文件存不存在无关。查问题时别被这句话带偏。

## 最终方案：一个专用调试 Chrome

### 1. 启动脚本

`~/.local/bin/chrome-mcp`：

```bash
#!/bin/sh
exec /usr/bin/google-chrome-stable \
  --user-data-dir="$HOME/.local/share/chrome-mcp/profile" \
  --remote-debugging-port=9223 \
  --ozone-platform=x11 \
  --class=mcp-chrome \
  --no-first-run --no-default-browser-check "$@"
```

几个参数的作用：

| 参数 | 作用 |
|:--|:--|
| `--user-data-dir` | **非默认目录**，这是能开调试端口的前提 |
| `--remote-debugging-port=9223` | 固定端口，MCP 按这个连 |
| `--ozone-platform=x11` | 这台机器上配合 fcitx5 用，见[输入法那篇](/posts/fcitx5-rime-ice/) |
| `--class=mcp-chrome` | 窗口 WM_CLASS 单独设一个，dock 里能和日常 Chrome 区分开 |
| `--no-first-run --no-default-browser-check` | 新建 profile 时跳过欢迎页和"设为默认浏览器" |

### 2. 桌面入口

复制系统自带的 desktop 文件，把所有 `Exec=` 行（普通、新窗口、隐身三个 Action 都要改）指向脚本：

```bash
sed -e 's|^Exec=/usr/bin/google-chrome-stable|Exec=/home/gobai/.local/bin/chrome-mcp|' \
    -e 's|^Name=Google Chrome$|Name=Chrome (MCP)|' \
    /usr/share/applications/google-chrome.desktop \
  > ~/.local/share/applications/chrome-mcp.desktop
```

再在 `[Desktop Entry]` 段加一行 `StartupWMClass=mcp-chrome`，和脚本的 `--class` 对应。

> 注意 `StartupWMClass` 只能放在 `[Desktop Entry]` 组里。塞到 `Desktop Action xxx` 组里 `desktop-file-validate` 会报错。

### 3. 启动

第一次手动跑一次，在弹出的窗口里登录需要的账号：

```bash
~/.local/bin/chrome-mcp
```

登录态就落在 `~/.local/share/chrome-mcp/profile` 里，之后每次启动都还在。

**让它长期在后台活着**，不要在终端里 `&`。我试过两种都会死：

- `setsid ... &`：Claude Code 的工具调用结束后，进程跟着 cgroup 一起被回收
- 直接 `systemd-run --user --collect`：少了 `DISPLAY` / `XAUTHORITY`，Chrome 启动后几秒安静退出（exit 0，日志里就一句 `Requested load of chrome://newtab/ for incorrect profile type`）

正确的写法要带上 X 授权文件：

```bash
systemd-run --user --unit=chrome-mcp --collect \
  -p Environment=DISPLAY=:0 \
  -p Environment=XAUTHORITY=/run/user/1000/.mutter-Xwaylandauth.0622U3 \
  /home/gobai/.local/bin/chrome-mcp
```

`XAUTHORITY` 的路径可以从当前会话拿：`echo $XAUTHORITY`（X11 会话下是 `/run/user/1000/.mutter-Xwaylandauth.xxxxxx`，每次登录会变）。

### 4. MCP 配置

关掉插件自带的 server，在 `~/.claude.json` 里自己定义一份：

```json
"chrome-devtools": {
  "type": "stdio",
  "command": "npx",
  "args": ["chrome-devtools-mcp@latest", "--browserUrl=http://127.0.0.1:9223"]
}
```

`--browserUrl` 走 `puppeteer.connect()`，不启动浏览器。

### 5. 验证

```bash
curl -s http://127.0.0.1:9223/json/version
```

返回带 `webSocketDebuggerUrl` 的 JSON 就对了。

## 遇到的问题记录

**端口冲突**：先用的 9222，结果被日常 Chrome 占着——那是之前在 `chrome://inspect` 里开调试留下的监听，它不接受新的客户端（403）。`ss -lntp | grep 9222` 能看到是哪个 pid，换成 9223 即可。

**日志里 `Cannot start http server for devtools`**：就是端口被占，Chrome 不会退出，只是调试端口没起来，很容易被忽略。

**profile 坏了会导致 Chrome 启动后立刻退出**：前面反复 kill 了几次，profile 处于半写状态，Chrome 起来几秒就自己退了。删掉 `~/.local/share/chrome-mcp/profile` 重新登录一次就好。

**别用 `pkill -f '<profile路径>'` 杀自己**：这条命令会匹配到执行它的那个 shell 自己，命令直接以一个奇怪的退出码结束（144）。要么 `pgrep -f` 先看一眼 pid，要么用 systemd 单元 `systemctl --user stop chrome-mcp`。

## 让调试 Chrome 单独占用一个工作区

调试用的 Chrome 一直在主工作区里晃，切窗口时很容易点到它。想让它固定待在自己的工作区，先试了最直接的路子：

```bash
xdotool set_desktop_for_window <win_id> 3
```

`xdotool` 返回 0，看起来成功了，但 `_NET_WM_DESKTOP` 还是 0，窗口没动。原因是被测环境是 **GNOME Wayland 会话**，Chrome 走 `--ozone-platform=x11` 是 XWayland 客户端，mutter 对 XWayland 客户端并不提供 EWMH 多工作区支持——`xdotool get_num_desktops` 在这个会话里只返回 2，`set_desktop_for_window` 发出的请求直接被丢掉。所以凡是靠 EWMH 移动窗口的工具（wmctrl、xdotool、devilspie 之类）在 Wayland 下都不好使。

改用 GNOME 官方扩展 `auto-move-windows`，按 desktop 文件 id 匹配窗口，新窗口一出现就送过去：

```bash
sudo apt install -y gnome-shell-extensions

# 规则格式是 <desktop文件id>:<工作区序号，从1开始>
gsettings set org.gnome.shell.extensions.auto-move-windows application-list "['chrome-mcp.desktop:4']"

# 顺便给工作区起名，Super+4 一眼能认出来
gsettings set org.gnome.desktop.wm.preferences workspace-names "['主','','','MCP']"
```

两个坑：

- **规则要写 desktop 文件 id，不是 `WM_CLASS`**。扩展内部走 `Shell.AppSystem.lookup_app(id)`，写成 `mcp-chrome:4` 匹配不到任何 app，而且**不报错**，就是不生效。应该是 `chrome-mcp.desktop:4`。
- **新装的扩展当场 `gnome-extensions enable` 会报 "does not exist"**。GNOME Shell 只在启动时扫一遍扩展目录，运行时新增的看不见。要直接写 gsettings：

  ```bash
  gsettings set org.gnome.shell enabled-extensions "$(gsettings get org.gnome.shell enabled-extensions | sed "s/]$/, 'auto-move-windows@gnome-shell-extensions.gcampax.github.com']/")"
  ```

  然后注销重新登录。`busctl ... Eval "global.reexec_self()"` 在 Ubuntu 默认配置下被 `unsafe-mode` 挡掉（返回 `bs false ""`），别指望它热重载。

另外 `num-workspaces` 要 ≥ 目标序号，并且 `dynamic-workspaces` 为 `false`。动态工作区下扩展会自己 `append_new_workspace` 补位，但补出来的序号是登录后的运行态，不如固定 4 个稳妥。

这个方案的效果：**Chrome 窗口落在 4 号工作区，启动、新开窗口、`--incognito` 都会自动过去；主工作区完全不被打扰。** 想直接看它，`Super+4`；想让 MCP 在那边默默跑，什么都不用做。

## 代价与取舍

- **登录态是独立的**：日常 Chrome 里登录的站点不会自动同步过来，这个调试 profile 要单独登录一次。反过来也有好处——它只有你主动登录过的东西，不容易误操作到主账号。
- **9223 对本机所有进程开放**：谁能跑命令谁就能读这个 profile 的全部 cookie。端口绑定在 `127.0.0.1`，外网进不来，但机器上有别人或可疑进程时要想清楚。
- **多会话共用一个浏览器会看到彼此的 tab**：`list_pages` 会列出所有人的页面，且 pageId 是每个 MCP 进程各自编号的，不同会话看到的 id 不一样。约定每个 agent 只 `new_page` 自己的页面、`select_page` 选中后再操作，别碰别人的。

## 总结

| 方案 | 弹 Allow | 共享登录态 | 额外 Chrome 进程 |
|:--|:--|:--|:--|
| 插件默认（`--headless --isolated`） | 否 | ❌ | 每会话一个 |
| 日常 Chrome + `chrome://inspect` | ✅ 每连接一次 | ✅ | 否 |
| 日常 Chrome + `--remote-debugging-port` | — | ✅ | — （136+ 根本不可行） |
| **独立 profile + `--browserUrl`** | 否 | ✅（同一 profile） | 否 |
| **独立 profile + agent-browser `--cdp`（见下方更新）** | 否 | ✅（同一 profile） | 否，且没有常驻 MCP 进程 |

唯一需要接受的是"登录态和日常浏览器分开"，换来的是完全不需要点弹窗、不需要关日常 Chrome、也不会每个会话多一个进程。

## 2026-11 更新：省下来的是内存，烧掉的是 token

> 环境：Claude Code 2.1.319 + chrome-devtools-mcp 1.12 + agent-browser 0.41.2

上面的方案用了三周，Chrome 确实只有一个了。但回头翻 Claude Code 的 transcript 算了笔账，发现方向有点偏：Chrome 从来不是大头。

### 真正占内存的是 MCP 进程，不是 Chrome

```bash
ps -eo pid,ppid,rss,etime,args | grep '[c]hrome-devtools-mcp'
```

| 项目 | 数量 | 常驻内存 |
|:--|:--|:--|
| 9223 上的 Chrome（含渲染子进程） | 1 组 | 约 250 MB |
| chrome-devtools-mcp 进程树（npx → sh → node → watchdog） | 24 组 | 约 2.3 GB |

每个 `claude --resume` 会话都挂着自己的一份 MCP server。新起的每组 300 MB 左右，放了两周的被换出到十几 MB，但一个都没退。24 个全是"活的"，父进程都在，所以也没法当孤儿清。

共享 Chrome 省下的是 N 个浏览器，换来的是 N 个 node 进程。净收益有，但没有想象的大。

### 比内存贵得多的是 token

同一份 transcript 统计了 30 天内各工具返回给模型的字节数：

| 工具 | 总字节 | 调用次数 |
|:--|--:|--:|
| `take_screenshot` | 26.3 MB | 209 |
| exa `web_search` | 6.5 MB | 294 |
| `take_snapshot` / `evaluate_script` / `wait_for` 合计 | 约 0.9 MB | 约 600 |

209 次截图里 **180 次是主会话模型直接消费的**，只有 29 次在子代理里。换句话说最贵的模型在亲自看图。再加上 chrome-devtools-mcp 默认 32 个工具的定义（约 17K token）每轮都进上下文，这才是账单的主体。

### 第一步：把浏览器操作整体隔离到一个便宜的子代理

Claude Code 支持在 agent 定义里内联 MCP server。这样主模型既看不到工具定义，也收不到截图，只拿到子代理最后那段文字总结。配合 `CLAUDE_CODE_SUBAGENT_MODEL` 把子代理指到便宜模型，隔离和降级一起做。

`~/.claude/agents/browser.md` 的 frontmatter（MCP 版）：

```yaml
---
name: browser
model: deepseek-v4.1-flash
maxTurns: 40
disallowedTools: Agent, Edit, Write
mcpServers:
  - chrome-devtools:
      type: stdio
      command: npx
      args:
        - chrome-devtools-mcp@latest
        - --browserUrl=http://127.0.0.1:9223
        - --screenshotFormat=jpeg
        - --screenshotQuality=60
        - --screenshotMaxWidth=1024
---
```

然后把 `~/.claude.json` 里全局的 chrome-devtools 条目删掉，否则主模型还是能直接调。

踩的坑：

- **`mcpServers` 必须写成 YAML 列表，每项一个单键对象。** 写成普通 map 会被**静默忽略**，子代理起来只有 Read 和 Bash，一句警告都没有。翻二进制才看到解析那段是 `Array.isArray(...)` 才处理。
- **`CLAUDE_CODE_SUBAGENT_MODEL` 优先级最低。** Agent 调用时传的 model 参数、agent 定义里的 `model:`（包括 `inherit`）都压得过它，内置 Explore 也不听它的。要全覆盖得再加 `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`。两个变量放进 `settings.json` 的 `env` 块，不要只放 `.zshrc`，否则 IDE 扩展和 tmux 新窗口起的 Claude 拿不到。
- **`claude -p` 非交互模式下 MCP 工具默认拒绝**，要 `--allowedTools "mcp__chrome-devtools__*"`。多个值用逗号连成一个参数，prompt 走 stdin，否则报 `Input must be provided either through stdin or as a prompt argument`。

### 第二步：MCP 换成 CLI

2026 年下半年几份独立测评（browser-use 公司、Doccraft 等）结论一致：让 coding agent 通过 MCP 工具 schema 操作浏览器天生贵，连 Playwright MCP 自己的 README 都在劝人改用 CLI 加 skill。原因就两条：工具定义每轮重复进上下文；每个动作都回传一大段页面状态。CLI 没有这两项，点击成功只返回 `Done`。

选了 Vercel 的 [agent-browser](https://github.com/vercel-labs/agent-browser)：Rust 单二进制，`npm i -g` 装，`snapshot -i` 输出无障碍树带 `@e1` 这种 ref，关键是支持 `--cdp` 直接连已有 Chrome，9223 那个实例不用动。

```bash
npm i -g agent-browser
agent-browser --cdp http://127.0.0.1:9223 open http://127.0.0.1:5175/
agent-browser --cdp http://127.0.0.1:9223 snapshot -i
```

browser agent 改成不挂 MCP，只给 Bash 跑这个 CLI。同一个任务（打开本地登录页，报标题、标题层级、前 5 个可交互元素、console 错误）三个版本的实测：

| | MCP 版 | CLI 版初稿 | CLI 版加了踩坑说明 |
|:--|--:|--:|--:|
| 子代理轮次 | 19 | 12 | 10 |
| 新输入 token | 20,817 | 12,190 | 11,488 |
| 缓存读取 token | 50,304 | 69,376 | 39,168 |
| 输出 token | 1,433 | 1,816 | 915 |
| 子代理费用 | $0.122 | $0.099 | $0.072 |
| 耗时 | 53 s | 55 s | 41 s |

没有出现测评里 5 到 10 倍的差距，原因是第一步的隔离已经把工具定义挡在主模型外面了，子代理自己看到的 MCP 工具定义只有 12KB 左右，和 CLI 版默认工具集差不多。对我这套配置来说，**真正的省钱是隔离那一步，CLI 替换是锦上添花**。CLI 的额外收益是主模型连 32 个工具定义都不加载，以及不会再堆出 24 个常驻 node 进程：agent-browser 每次起一个后台 daemon 连 Chrome，一小时没命令自动退出。

### 便宜模型用 CLI 会踩什么坑

CLI 版初稿里 deepseek 多跑了两轮试探，看 transcript 都是可以提前写进 agent 提示词里的：

- **命令前缀不能放 shell 变量。** 模型很自然地写 `A="agent-browser --cdp ..."; $A snapshot`，Claude Code 的权限检查器拒绝带变量展开的命令：`A variable in this command can't be checked before it runs`。只能每次把前缀完整打出来，多条命令用 `;` 串在一个 Bash 调用里。
- **ref 只在产生它的那次 Bash 调用里有效。** 每次 `snapshot` 编号都重排，隔一轮再用 `@e4` 就是 `✗ Unknown ref`。要么 `snapshot -i; click @eN` 写在一起，要么用 `find role button click --name "Sign in"` 这类语义定位。
- **`errors` 没有错误时什么都不打印，退出码 0。** 模型不信，又用 `cat -A` 和 `--json` 验了一遍。得明说"空输出就是答案"。
- **`eval` 外层单引号、里面双引号**，箭头函数、`?.`、展开、IIFE 都能用，结果按 JSON 打印。
- **snapshot 里的标签是无障碍名**，和 placeholder、title 不一定一致，无标签的 `button [ref=eN]` 可能有 title 属性。要标签就用一条 `eval` 一次性拉全 `{tag,type,text,placeholder,ariaLabel,title,disabled}`。
- **别用 `--json`**，会带一大块 `lifecycle` 元数据。
- 别装它那个 14K token 的完整 skill。Doccraft 的测试里完整 skill 反而是 CLI 配置里最贵的，README 推荐的 4 行 AGENTS.md 说明才是最省的那档。

把这些写进 agent 提示词后就是上表最右那一列：0 次出错，轮次和费用都下来了。

### 顺带发现：systemd 单元早就没了

写这篇时 9223 上跑的其实是一个 11 天前手动起的 `--headless=new --user-data-dir=/tmp/chrome-pdbench` 实例，父进程是 1，是某次做 benchmark 顺手开的，恰好占了同一个端口。`systemctl --user` 里 `chrome-mcp` 单元已经不在了，`~/.local/bin/chrome-mcp` 脚本还在但没人调。"一个 Chrome 服务所有会话"这个目标过去三周是靠巧合维持的，重启机器就没了。要恢复的话把脚本改成 headless 参数再挂回 `systemd-run --user`，profile 用固定目录别用 `/tmp`。

性能 trace、Lighthouse、带 source map 的 console 堆栈这些 DevTools 深度能力 agent-browser 没有那么全，这类需求可以把 MCP 版 agent 定义留着当第二个子代理，只在调性能时派。

参考：

- [Changes to remote debugging switches to improve security](https://developer.chrome.com/blog/remote-debugging-port)
- [chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp)
- [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser)
- [Playwright MCP vs Chrome DevTools MCP vs agent-browser: same accuracy, but tokens per task ranged from 4.1K to 95K](https://doccraft.dev/blog/playwright-mcp-vs-devtools-mcp-vs-agent-browser)
- [Claude Code 文档：Subagents](https://code.claude.com/docs/en/sub-agents)
