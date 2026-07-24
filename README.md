# dotfiles

个人 Bash、Zsh、Vim、LazyVim 和 Tmux 配置。安装脚本不会使用 `sudo`；冲突的配置会先移动到带时间戳的 `.dotfiles-backup-*` 路径。

## 可选安装

```bash
# 安装私有 Zsh 到 ~/.local，同时安装离线插件并链接 ~/.zshrc
./install.sh --zsh

# 只链接 LazyVim 配置
./install.sh --lazyvim

# 两项都安装
./install.sh --all
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
