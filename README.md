# dotfiles

个人 Bash、Zsh、Vim、LazyVim 和 Tmux 配置。安装脚本不会使用 `sudo`；冲突的配置会先移动到带时间戳的 `.dotfiles-backup-*` 路径。

## 可选安装

```bash
# 安装 Bash Prompt、Conda/Git 提示和 ble.sh 命令联想
./install.sh --bash

# 安装私有 Zsh 到 ~/.local，同时安装离线插件并链接 ~/.zshrc
./install.sh --zsh

# 只链接 LazyVim 配置
./install.sh --lazyvim

# 可选安装 Anaconda Distribution（不会被 --all 自动选择）
./install.sh --anaconda

# 安装 Bash、Zsh 和 LazyVim
./install.sh --all

# 上述全部组件再加 Anaconda
./install.sh --all --anaconda
```

`--bash` 会安装固定版本的 `ble.sh` 到 `~/.local/share/blesh`，并把 `~/.bashrc` 链接到仓库配置。Bash Prompt 显示 Conda 环境、上一条命令状态、当前路径、Git 分支和工作区状态，例如：

```text
(base) ✔ ~/data/personal/dotfiles [master|✔]
11:28 $
```

离线安装 `ble.sh` 时，先下载官方 `ble-0.4.0-devel3.tar.xz` 并复制到服务器：

```bash
curl -LO https://github.com/akinomyoga/ble.sh/releases/download/v0.4.0-devel3/ble-0.4.0-devel3.tar.xz
./install.sh --bash --ble-archive /path/to/ble-0.4.0-devel3.tar.xz
```

Zsh Prompt 会在最前面显示短机器名，例如 `amax ➜ dotfiles git:(master)`。

## 可选安装 Anaconda

`--anaconda` 会根据 Linux 架构选择官方 Anaconda Distribution `2025.12-2` 安装包，校验 SHA-256 后静默安装到 `~/anaconda3`，不需要 root 权限，也不会运行 `conda init` 去改写仓库管理的 shell 配置。现有 Bash/Zsh 配置会在下一次启动时自动加载它：

```bash
./install.sh --anaconda
exec "$HOME/.local/bin/zsh"  # 或 exec bash
conda --version
```

Anaconda 安装包约 1.0–1.2 GB，官方要求至少 5 GB 可用磁盘空间；当前 Linux 安装包要求 glibc 2.28 或更新版本。Anaconda 的使用还受其许可条款约束，特别是较大的商业组织应先确认授权要求。

离线服务器可以先下载与架构匹配的官方安装包并复制过去：

```bash
# Linux x86_64
curl -LO https://repo.anaconda.com/archive/Anaconda3-2025.12-2-Linux-x86_64.sh
./install.sh --anaconda \
  --anaconda-archive /path/to/Anaconda3-2025.12-2-Linux-x86_64.sh
```

LazyVim 要求 Neovim 0.11.2 或更新版本以及 Git。第一次运行 `nvim` 时会联网下载插件；完成后可运行 `:LazyHealth` 检查环境。

Zsh 默认从官方地址下载 5.9.2 源码，校验 SHA-256 后编译到 `~/.local`。需要 C 编译器、`make`、`tar`、`xz`、`gzip`，在线安装还需要 `curl` 或 `wget`；不需要 root 权限。如果服务器缺少 ncurses 开发包，脚本会自动下载并编译一份私有 ncurses 6.6。安装后运行：

```bash
exec ~/.local/bin/zsh
```

在离线服务器上，先在联网机器下载官方源码包并将它复制过去，然后使用仓库中已经自带的离线插件：

```bash
curl -LO https://www.zsh.org/pub/zsh-5.9.2.tar.xz
curl -LO https://ftp.gnu.org/gnu/ncurses/ncurses-6.6.tar.gz
./install.sh --zsh \
  --zsh-archive /path/to/zsh-5.9.2.tar.xz \
  --ncurses-archive /path/to/ncurses-6.6.tar.gz
```

自定义源码版本时，需要同时提供校验值：

```bash
ZSH_VERSION=5.9.2 ZSH_SHA256=... ./install.sh --zsh
```
