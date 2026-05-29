# easy-fzf

一份为 Zsh 用户精心配置的 [fzf](https://github.com/junegunn/fzf) 集成脚本，提供开箱即用的快捷键绑定、文件/目录/历史搜索、实时内容搜索以及智能补全体验。

## 功能一览

| 快捷键 | 功能 |
|--------|------|
| `Ctrl-T` | 文件选择器，支持预览，按 `Enter` 用 vim 打开，`Ctrl-V` 用 VSCode，`Ctrl-O` 在 Finder 中显示 |
| `Alt-C` | 目录选择器，带 `tree` 预览，选中后自动 `cd` |
| `Ctrl-R` | 历史命令搜索，按 `Ctrl-/` 切换预览 |
| `Ctrl-G` | 实时 ripgrep 全文搜索，匹配行直接跳转 vim 或 VSCode |
| `**<Tab>` | 模糊补全触发（如 `vim **<Tab>`、`cd **<Tab>`） |

## 依赖

在使用本脚本前，请确保以下工具已安装：

```bash
# macOS (Homebrew)
brew install fzf fd ripgrep tree chafa
```

| 工具 | 用途 |
|------|------|
| [oh-my-zsh](https://ohmyz.sh/) | Zsh 框架，脚本放置于其 `custom/` 目录下自动加载 |
| [fzf](https://github.com/junegunn/fzf) | 核心模糊查找引擎 |
| [fd](https://github.com/sharkdp/fd) | 替代 `find`，默认忽略 `.gitignore`，支持隐藏文件 |
| [ripgrep (rg)](https://github.com/BurntSushi/ripgrep) | `Ctrl-G` 实时全文搜索 |
| [tree](http://mama.indstate.edu/users/ice/tree/) | 目录预览 |
| [chafa](https://hpjansson.org/chafa/) | 终端内图片预览 |
| vim / [VSCode](https://code.visualstudio.com/) | 文件打开器 |

> 本脚本依赖 `scripts/fx-preview.sh` 用于文件内容预览（含图片预览）。安装时请将其一并复制到 `~/.oh-my-zsh/custom/scripts/` 并确保可执行。

## 安装

**前提：已安装 [oh-my-zsh](https://ohmyz.sh/)**

1. 将 `fzf.zsh` 和预览脚本复制到 oh-my-zsh 自定义目录：

```zsh
cp fzf.zsh ~/.oh-my-zsh/custom/
cp scripts/fx-preview.sh ~/.oh-my-zsh/custom/scripts/
chmod +x ~/.oh-my-zsh/custom/scripts/fx-preview.sh
```

oh-my-zsh 会自动 source `custom/` 目录下的所有 `.zsh` 文件，无需手动引入。

2. 重新加载配置：

```zsh
source ~/.zshrc
```

## 使用说明

### Ctrl-T — 文件选择器

在命令行中按 `Ctrl-T`，弹出文件选择面板，右侧显示文件预览。

- `Enter` — 在 vim 中打开
- `Ctrl-V` — 在 VSCode 中打开
- `Ctrl-O` — 在 Finder 中显示（目录则直接打开）

### Alt-C — 目录跳转

按 `Alt-C`，以 `tree` 预览选择目录，选中后自动执行 `cd`。

### Ctrl-R — 历史命令搜索

按 `Ctrl-R`，模糊搜索历史命令，按 `Ctrl-/` 展开/收起命令预览。

### Ctrl-G — 实时全文搜索

按 `Ctrl-G`，通过 ripgrep 在当前目录下实时搜索文件内容：

- 实时输入关键词，结果即时刷新
- 预览窗口高亮匹配行
- `Enter` — 在 vim 中跳到对应行
- `Ctrl-V` — 在 VSCode 中跳到对应行

### `**` 模糊补全

在支持路径的命令后输入 `**` 再按 `Tab`，触发 fzf 补全：

```zsh
vim **<Tab>       # 文件选择
cd **<Tab>        # 目录选择（带 tree 预览）
ssh **<Tab>       # 主机选择（带 dig 查询）
export **<Tab>    # 环境变量选择
```

## 配置说明

脚本中的关键配置项：

```zsh
# 默认搜索命令：包含隐藏文件，排除 .git
export FZF_DEFAULT_COMMAND='fd --hidden --follow --exclude .git'

# 全局 UI：顶部输入框，50% 高度，带边框
export FZF_DEFAULT_OPTS='--layout=reverse --height=50% --border'
```

如需调整预览脚本路径或修改快捷键绑定，直接编辑 `fzf.zsh` 对应配置项即可。
