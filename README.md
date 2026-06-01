# easy-iterm

一份为 macOS + Zsh 用户整理的终端增强工具手册，涵盖常用现代 CLI 工具的安装、配置与日常用法。

## 安装（一键）

```bash
brew install fzf fd ripgrep bat git-delta lsd ncdu duf starship fnm curlie tree chafa
```

---

## 工具一览

| 工具 | 替代 | 简介 |
|------|------|------|
| [fd](#fd) | `find` | 更快的文件查找（fzf 依赖） |
| [ripgrep](#ripgrep-rg) | `grep` | 更快的代码全文搜索（fzf 依赖） |
| [bat](#bat) | `cat` | 语法高亮文件查看器（fzf 预览依赖） |
| [fzf](#fzf) | — | 模糊搜索核心引擎 |
| [lsd](#lsd) | `ls` | 彩色目录列表 |
| [duf](#duf) | `df` | 磁盘挂载点总览 |
| [ncdu](#ncdu) | `du` | 交互式磁盘用量分析 |
| [git-delta](#git-delta) | — | git diff 增强渲染 |
| [starship](#starship) | — | 跨 Shell 提示符 |
| [fnm](#fnm) | `nvm` | Node.js 版本管理 |
| [curlie](#curlie) | `curl` | 友好的 HTTP 客户端 |

---

## fd

`find` 的现代替代，默认遵循 `.gitignore`、支持隐藏文件。

```bash
brew install fd
```

**常用示例：**

```bash
fd <pattern>                 # 在当前目录递归搜索文件名
fd -e zsh                    # 只搜索 .zsh 文件
fd --hidden --exclude .git   # 包含隐藏文件，排除 .git
fd -t d src                  # 只搜索目录
```

---

## ripgrep (`rg`)

比 `grep` 快数倍的全文搜索工具，自动忽略 `.gitignore`。

```bash
brew install ripgrep
```

**常用示例：**

```bash
rg <pattern>                 # 在当前目录递归搜索
rg -l <pattern>              # 只列出匹配文件名
rg -n --color=always <word>  # 带行号和高亮
rg -t zsh <pattern>          # 只搜索 .zsh 文件
```

---

## bat

`cat` 的替代，带语法高亮、行号与 git 差异标记。

```bash
brew install bat
```

**常用示例：**

```bash
bat <file>                   # 查看文件（自动高亮）
bat -n <file>                # 显示行号
bat --style=plain <file>     # 无装饰，纯内容输出
bat -l json <file>           # 指定语言高亮
```

> `bat` 可作为 `fzf` 的预览命令，本仓库的 `fx-preview.sh` 已集成。

---

## fzf

模糊搜索引擎，本仓库提供完整的 Zsh 集成配置（`fzf.zsh`）。

**安装并加载 Zsh 集成：**

```bash
brew install fzf
cp fzf.zsh ~/.oh-my-zsh/custom/
cp scripts/fx-preview.sh ~/.oh-my-zsh/custom/scripts/
chmod +x ~/.oh-my-zsh/custom/scripts/fx-preview.sh
source ~/.zshrc
```

**快捷键：**

| 快捷键 | 功能 |
|--------|------|
| `Ctrl-T` | 文件选择器，`Enter` 用 vim 打开，`Ctrl-V` 用 VSCode，`Ctrl-O` 在 Finder 中显示 |
| `Alt-C` | 目录跳转，带 `tree` 预览 |
| `Ctrl-R` | 历史命令搜索，`Ctrl-/` 切换预览 |
| `Ctrl-G` | ripgrep 实时全文搜索，跳转到匹配行 |
| `**<Tab>` | 模糊补全触发（`vim **<Tab>`、`cd **<Tab>` 等） |

详见 [fzf.zsh](fzf.zsh)。

---

## lsd

彩色 `ls` 替代，支持图标与树形视图。已设别名：

```zsh
alias lsd='lsd -l'   # 默认长格式
```

```bash
brew install lsd
```

**常用示例：**

```bash
lsd                  # 长格式列表（别名已默认）
lsd -a               # 含隐藏文件
lsd --tree           # 树形展开
lsd --tree --depth 2 # 限制展开深度
```

---

## duf

`df` 的可读替代，彩色展示所有挂载点的用量。

```bash
brew install duf
```

```bash
duf           # 显示所有挂载点
duf /dev/sda  # 只显示指定设备
```

---

## ncdu

交互式磁盘用量分析，快速定位"谁占了磁盘"。

```bash
brew install ncdu
```

**使用方式：**

```bash
ncdu          # 分析当前目录
ncdu /        # 分析根目录（需要权限）
ncdu ~        # 分析主目录
```

界面内 `d` 删除选中项，`q` 退出。

---

## git-delta

`git diff` / `git log` 的增强渲染，支持语法高亮与行内差异。

```bash
brew install git-delta
```

**常用示例：**

```bash
# 直接 pipe，无需任何配置
git diff | delta
git diff | delta -s          # -s / --side-by-side 并排对比
git show HEAD | delta
git log -p | delta
```

**可选：集成到 ~/.gitconfig（让 git 命令自动使用 delta）**

```ini
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    light = false

[merge]
    conflictstyle = diff3

[diff]
    colorMoved = default
```

---

## starship

跨 Shell 提示符，配置文件位于 `~/.config/starship.toml`（已有定制配置）。

```bash
brew install starship
```

**~/.zshrc 中启用：**

```zsh
eval "$(starship init zsh)"
```

**下载预设主题：**

```bash
# 以 catppuccin-powerline 为例，覆盖写入配置文件
starship preset catppuccin-powerline -o ~/.config/starship.toml
```

**定制项（在 `~/.config/starship.toml` 中修改）：**

```toml
# 切换 Catppuccin 变体：frappe / mocha / macchiato / latte
palette = 'catppuccin_frappe'

# 显示完整路径，不截断到 repo 根目录
[directory]
truncate_to_repo = false
truncation_length = 0
truncation_symbol = ""

# 两行提示符，输入命令始终从新行开始
[line_break]
disabled = false
```

详见 [Starship 文档](https://starship.rs/config/) 与 [预设列表](https://starship.rs/presets/)。

---

## fnm

Node.js 版本管理，比 `nvm` 更快（Rust 实现）。

```bash
brew install fnm
```

**~/.zshrc 中启用：**

```zsh
eval "$(fnm env --use-on-cd)"
```

**常用示例：**

```bash
fnm list                 # 列出已安装版本
fnm install 20           # 安装 Node.js 20.x
fnm use 20               # 切换到 Node.js 20
fnm default 20           # 设为默认版本
```

---

## curlie

`curl` 的友好封装，自动格式化 JSON 响应，保留 curl 全部能力。

```bash
brew install curlie
```

**常用示例：**

```bash
curlie https://httpbin.org/get            # GET，自动格式化输出
curlie POST https://api.example.com/data  # POST（类 HTTPie 语法）
curlie -H "Authorization: Bearer <token>" https://api.example.com/me

# 查看等价的原始 curl 命令（调试用）
curlie --curl https://httpbin.org/get
```

> `curlie --curl <args>` 会输出对应的 curl 命令而不执行，方便复制到脚本或 CI。
