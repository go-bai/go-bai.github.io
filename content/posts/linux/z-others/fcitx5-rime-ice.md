---
title: "Ubuntu 22.04 GNOME Wayland 配置 fcitx5 + 雾凇拼音"
date: 2026-10-05T10:00:00+08:00
---

> 以下配置都是在 `Ubuntu 22.04` + `GNOME 42 Wayland` 下完成的

之前一直用系统自带的 `ibus` 智能拼音，词库弱、新词基本打不出来，Chrome 在 Wayland 下输入法还时好时坏。这次换成了 `fcitx5` + [雾凇拼音 (rime-ice)](https://github.com/iDvel/rime-ice)，**比以前好用太多了**，下面记录一下完整配置和踩过的坑。

最终效果：

- 只保留一个输入法 `Rime 雾凇拼音`，`Shift` 切换中/英
- 新词、长句联想很准，比如 `jushenzhineng` → `具身智能`
- 自带一堆 Lua 扩展：`rq` 日期、`sj` 时间、`xq` 星期、`nl` 农历、`R1234` 数字大写、`cC1+2` 计算器、`uuid`

## 安装 fcitx5 和 Rime

```bash
sudo apt install -y fcitx5 fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 fcitx5-config-qt \
  fcitx5-rime librime-plugin-lua librime-bin
```

- `fcitx5` 是输入法框架，`Rime` 是跑在它上面的输入引擎，雾凇拼音是 Rime 的一套配置和词库
- `librime-plugin-lua` 必须装，雾凇的日期、计算器等功能都是 Lua 写的
- 不需要装 `fcitx5-chinese-addons`（fcitx5 自带拼音），只用雾凇的话装了反而多一个输入法要切

## 切换系统输入法框架为 fcitx5

```bash
im-config -n fcitx5
```

会生成 `~/.xinputrc`，内容是 `run_im fcitx5`。

再写一份环境变量 `~/.config/environment.d/90-fcitx5.conf`

```ini
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
```

开机自启

```bash
cp /usr/share/applications/org.fcitx.Fcitx5.desktop ~/.config/autostart/
```

GNOME 自己的输入源只留英文键盘，不然 GNOME 会和 fcitx5 抢 `Super+Space`

```bash
# 先备份原值
gsettings get org.gnome.desktop.input-sources sources > ~/gnome-input-sources.bak
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us')]"
```

然后注销重新登录。

### 坑：用户开启了 linger，重新登录环境变量也不生效

如果 `loginctl show-user $USER | grep Linger` 是 `Linger=yes`，`systemd --user` 会一直常驻，`environment.d` 只在它启动时读一次，注销重新登录也不会重新加载。需要手动推一下

```bash
systemctl --user set-environment GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx SDL_IM_MODULE=fcitx
```

## 安装雾凇拼音

fcitx5-rime 的用户目录是 `~/.local/share/fcitx5/rime`，直接下载 release 里的 `full.zip` 解压进去

```bash
mkdir -p ~/.local/share/fcitx5/rime && cd ~/.local/share/fcitx5/rime
wget https://github.com/iDvel/rime-ice/releases/download/2026.06.30/full.zip
unzip -o full.zip && rm full.zip
```

自定义配置写在 `default.custom.yaml`，不要直接改 `default.yaml`，升级时会被覆盖

```yaml
patch:
  "menu/page_size": 7
  # Shift 切换中英文时，把已输入的编码直接上屏
  "ascii_composer/switch_key/Shift_L": commit_code
  "ascii_composer/switch_key/Shift_R": commit_code
```

### 坑：librime-lua 1.7.3 不认识 `@*` 写法，候选全没了

部署完一打字，**一个候选都没有**。原因是 Ubuntu 22.04 源里的 `librime-plugin-lua` 是 1.7.3，太老了。雾凇 schema 里的 Lua 组件写法是新版的

```yaml
- lua_translator@*date_translator
```

`@*` 表示直接 `require` lua 目录下的模块，老版本不支持这个语法，而且**不报错**：translator 静默无输出，filter 直接把所有候选清空（日志里能看到 `upvalue 'f'` 为 nil）。

解决办法是改回老版本的写法 `lua_translator@date_translator`，老版本会去全局变量里找同名的函数，所以要再加一个 `rime.lua` 把模块导出成全局变量。

`~/.local/share/fcitx5/rime/rime.lua`

```lua
-- 兼容 librime-lua 1.7.3：旧版不支持 schema 里的 @*module 写法，这里把模块导出成全局变量
autocap_filter = require("autocap_filter")
calc_translator = require("calc_translator")
corrector = require("corrector")
date_translator = require("date_translator")
force_gc = require("force_gc")
long_word_filter = require("long_word_filter")
lunar = require("lunar")
number_translator = require("number_translator")
pin_cand_filter = require("pin_cand_filter")
reduce_english_filter = require("reduce_english_filter")
search = require("search")
select_character = require("select_character")
unicode = require("unicode")
uuid = require("uuid")
v_filter = require("v_filter")
```

然后用 `rime_ice.custom.yaml` 把 `engine` 下的 `processors / segmentors / translators / filters` 整个覆盖一遍，所有 `@*` 换成 `@`。列表比较长，手写容易漏，我用脚本从 `rime_ice.schema.yaml` 自动生成，生成结果大概是这样

```yaml
patch:
  "engine/translators":
    - lua_translator@date_translator
    - lua_translator@lunar
    - lua_translator@uuid
    # ...
  "engine/filters":
    - lua_filter@corrector
    - lua_filter@autocap_filter
    # ...
```

生成脚本 `rime-ice-compat-patch.py`

```python
import sys, re, os
# 从 rime_ice.schema.yaml 抽出 engine 各列表，去掉指定的 lua 组件，生成 rime_ice.custom.yaml
drop = set(sys.argv[1:])
src = open(os.path.expanduser('~/.local/share/fcitx5/rime/rime_ice.schema.yaml')).read()
eng = src.split('\nengine:\n',1)[1]
eng = re.split(r'\n(?=[a-z_]+:)', eng, 1)[0]
out = ['patch:']
cur = None
for line in eng.splitlines():
    m = re.match(r'\s+(processors|segmentors|translators|filters):', line)
    if m: cur = m.group(1); out.append(f'  "engine/{cur}":'); continue
    m = re.match(r'\s+- (\S+)', line)
    if m and cur:
        comp = m.group(1)
        name = comp.split('@*',1)[1].split('@')[0] if '@*' in comp else None
        if comp.startswith('lua_') and name not in drop: continue
        out.append(f'    - {comp.replace("@*", "@")}')
print('\n'.join(out))
```

再包一层 `rime-ice-redeploy.sh`，升级雾凇后跑一下就行（zsh 脚本）

```bash
#!/bin/zsh
# 升级 rime-ice 后运行：重新生成 librime-lua 1.7.3 兼容补丁并部署
set -e
R=~/.local/share/fcitx5/rime; T=~/.local/share/fcitx5/tools
MODS=(${(f)"$(grep -oE 'lua_[a-z]+@\*[a-z_]+' $R/rime_ice.schema.yaml | sed 's/.*@\*//' | sort -u)"})
{ echo '-- 兼容 librime-lua 1.7.3：旧版不支持 schema 里的 @*module 写法，这里把模块导出成全局变量'; for m in $MODS; do echo "$m = require(\"$m\")"; done; } > $R/rime.lua
{ echo '# 兼容 librime-lua 1.7.3（Ubuntu 22.04）：由 tools/rime-ice-redeploy.sh 生成，勿手改'; python3 $T/rime-ice-compat-patch.py $MODS; } > $R/rime_ice.custom.yaml
rime_deployer --build $R /usr/share/rime-data $R/build
echo "部署完成，重启 fcitx5 生效：fcitx5 -r -d"
```

> 改了 schema 之后 `fcitx5-remote -r` 不会重载 Rime 会话，要整个重启 fcitx5 `fcitx5 -r -d`

## fcitx5 配置

> fcitx5 退出时会把内存里的配置写回文件，所以手改下面的文件要**先停掉 fcitx5**（`fcitx5-remote -e`）再改，改完再启动，不然改了白改

### 只保留雾凇一个输入法

`~/.config/fcitx5/profile`

```ini
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=rime

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=rime
Layout=

[GroupOrder]
0=Default
```

### 用 Shift 切换中英文

`~/.config/fcitx5/config`

```ini
[Hotkey]
EnumerateWithTriggerKeys=True
EnumerateSkipFirst=False

[Hotkey/TriggerKeys]
0=Control+Shift+space

[Hotkey/AltTriggerKeys]

[Hotkey/PrevPage]
0=minus

[Hotkey/NextPage]
0=equal

[Behavior]
ActiveByDefault=True
ShareInputState=All
PreeditEnabledByDefault=True
ShowInputMethodInformation=True
DefaultPageSize=7
```

关键是 **清空 `AltTriggerKeys`**，`ActiveByDefault=True` 让 fcitx5 一直停在 Rime 上，中英文切换交给 Rime 自己的 `ascii_composer`（就是上面 `default.custom.yaml` 里的 `Shift_L: commit_code`）。

原因：fcitx5 的 `AltTriggerKeys`（默认是 Shift）只能撤销「由 Shift 造成的」切换。如果是 fcitx5 重启、托盘点击、或者 `Ctrl+Shift+Space` 切到的英文，再按 Shift 就切不回中文了，体验非常迷惑。

### 调大候选框字体

默认 `Sans 10` 在 2560x1440 的屏幕上太小了，`~/.config/fcitx5/conf/classicui.conf`

```ini
Font="Noto Sans CJK SC 14"
MenuFont="Noto Sans CJK SC 12"
TrayFont="Noto Sans CJK SC Bold 12"
Vertical Candidate List=False
PerScreenDPI=True
Theme=default
```

### 改掉和其他软件冲突的快捷键

fcitx5 剪贴板插件默认是 `Ctrl+;`，会和不少软件冲突，`~/.config/fcitx5/conf/clipboard.conf`

```ini
[TriggerKey]
0=Control+Alt+semicolon
```

## Chrome / VS Code 在 Wayland 下打不出中文

GNOME Wayland 的原生 `text-input` 协议只对接 `ibus`，Chrome 和 VS Code（Electron）如果跑在原生 Wayland 下就用不了 fcitx5。让它们走 `XWayland` 就好了。

把 desktop 文件复制到用户目录，`Exec` 行加上 `--ozone-platform=x11`

```bash
cp /usr/share/applications/google-chrome.desktop /usr/share/applications/code.desktop ~/.local/share/applications/
```

```diff
- Exec=/usr/bin/google-chrome-stable %U
+ Exec=/usr/bin/google-chrome-stable --ozone-platform=x11 %U
```

```diff
- Exec=/usr/share/code/code %F
+ Exec=/usr/share/code/code --ozone-platform=x11 %F
```

desktop 文件里每个 `Exec=` 行（包括新窗口、隐身窗口那几个 Action）都要改。

## 排查技巧

### 终端打不出中文，但 Chrome 可以

按键其实已经到 Rime 了，但终端里只显示英文字母、没有候选框。原因是这个 `gnome-terminal` 进程是在 fcitx5 被反复重启之前启动的，跟输入法的连接状态坏了。**新开的 GTK 程序都正常**，重启一下终端进程就好

```bash
systemctl --user restart gnome-terminal-server
```

经验：调配置时只要重启过 fcitx5，长期开着的程序（终端等）也顺手重开一下。只改雾凇配置的话，用托盘菜单里的「重新部署」就行，不用重启 fcitx5。

### 看按键到底有没有进 Rime

带详细日志重启 fcitx5（我这版 fcitx5 5.0.14 不支持运行时改日志级别，只能重启）

```bash
fcitx5 -r -d --verbose='key_trace=5,rime=5' > /tmp/fcitx5-trace.log 2>&1
```

打几个字之后看日志，`Rime receive key` + `result:1` 说明按键被 Rime 处理了，问题就在显示那一层。

> 这个日志会记录所有按键，看完记得正常重启 fcitx5 并删掉日志文件

### 诊断工具

```bash
fcitx5-diagnose
```

会检查环境变量、各个 GTK/Qt 输入法模块是否安装、当前运行状态，大部分配置问题都能直接看出来。

## 参考

- [雾凇拼音 rime-ice](https://github.com/iDvel/rime-ice)
- [Fcitx5 - ArchWiki](https://wiki.archlinux.org/title/Fcitx5)
- [Using Fcitx 5 on Wayland](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland)
