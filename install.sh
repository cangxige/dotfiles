#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

INSTALL_BASH=0
INSTALL_ZSH=0
INSTALL_LAZYVIM=0
INSTALL_ANACONDA=0
BLESH_ARCHIVE=""
BLESH_PREFIX="${BLESH_PREFIX:-$HOME/.local}"
FORCE_BLESH=0
ANACONDA_ARCHIVE=""
NVIM_ARCHIVE=""
FORCE_NVIM=0
ZSH_ARCHIVE=""
NCURSES_ARCHIVE=""
ZSH_PREFIX="${ZSH_PREFIX:-$HOME/.local}"
FORCE_ZSH=0

usage() {
  cat <<'EOF'
Usage:
  ./install.sh --bash [--ble-archive FILE] [--ble-prefix DIR] [--force-ble]
  ./install.sh --zsh [--zsh-archive FILE] [--ncurses-archive FILE]
                   [--zsh-prefix DIR] [--force-zsh]
  ./install.sh --lazyvim [--nvim-archive FILE] [--force-nvim]
  ./install.sh --anaconda [--anaconda-archive FILE]
  ./install.sh --all [bash and zsh options]

Options:
  --bash                Install ble.sh and link .bashrc
  --zsh                 Build a private zsh, install its plugins, and link .zshrc
  --lazyvim             Install Neovim and LazyVim without sudo
  --anaconda            Install Anaconda Distribution under ~/anaconda3
  --all                 Install Bash config, zsh, and LazyVim (not Anaconda)
  --ble-archive FILE    Install ble.sh from a local archive
  --ble-prefix DIR      Install ble.sh under DIR (default: ~/.local)
  --force-ble           Replace an existing ble.sh installation
  --anaconda-archive FILE
                        Install Anaconda from a local .sh installer
  --nvim-archive FILE   Install Neovim from a local official tarball
  --force-nvim          Reinstall the pinned Neovim version
  --zsh-archive FILE    Build zsh from a local source archive (for offline hosts)
  --ncurses-archive FILE
                        Use a local ncurses archive if system headers are missing
  --zsh-prefix DIR      Install zsh under DIR (default: ~/.local)
  --force-zsh           Rebuild zsh even when the requested version is installed
  -h, --help            Show this help

Existing config files are moved to a timestamped .dotfiles-backup-* path.
LazyVim plugins are restored from lazy-lock.json during installation.
EOF
}

while (($#)); do
  case "$1" in
    --bash)
      INSTALL_BASH=1
      shift
      ;;
    --zsh)
      INSTALL_ZSH=1
      shift
      ;;
    --lazyvim)
      INSTALL_LAZYVIM=1
      shift
      ;;
    --anaconda)
      INSTALL_ANACONDA=1
      shift
      ;;
    --all)
      INSTALL_BASH=1
      INSTALL_ZSH=1
      INSTALL_LAZYVIM=1
      shift
      ;;
    --anaconda-archive)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --anaconda-archive requires a file." >&2
        exit 2
      fi
      INSTALL_ANACONDA=1
      ANACONDA_ARCHIVE="$2"
      shift 2
      ;;
    --nvim-archive)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --nvim-archive requires a file." >&2
        exit 2
      fi
      INSTALL_LAZYVIM=1
      NVIM_ARCHIVE="$2"
      shift 2
      ;;
    --force-nvim)
      INSTALL_LAZYVIM=1
      FORCE_NVIM=1
      shift
      ;;
    --ble-archive)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --ble-archive requires a file." >&2
        exit 2
      fi
      INSTALL_BASH=1
      BLESH_ARCHIVE="$2"
      shift 2
      ;;
    --ble-prefix)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --ble-prefix requires a directory." >&2
        exit 2
      fi
      BLESH_PREFIX="$2"
      shift 2
      ;;
    --force-ble)
      INSTALL_BASH=1
      FORCE_BLESH=1
      shift
      ;;
    --zsh-archive)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --zsh-archive requires a file." >&2
        exit 2
      fi
      INSTALL_ZSH=1
      ZSH_ARCHIVE="$2"
      shift 2
      ;;
    --zsh-prefix)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --zsh-prefix requires a directory." >&2
        exit 2
      fi
      ZSH_PREFIX="$2"
      shift 2
      ;;
    --ncurses-archive)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --ncurses-archive requires a file." >&2
        exit 2
      fi
      INSTALL_ZSH=1
      NCURSES_ARCHIVE="$2"
      shift 2
      ;;
    --force-zsh)
      INSTALL_ZSH=1
      FORCE_ZSH=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$INSTALL_BASH" -eq 0 &&
      "$INSTALL_ZSH" -eq 0 &&
      "$INSTALL_LAZYVIM" -eq 0 &&
      "$INSTALL_ANACONDA" -eq 0 ]]; then
  usage >&2
  exit 2
fi

link_config() {
  local source_path="$1"
  local target_path="$2"
  local backup_path
  local timestamp

  mkdir -p "$(dirname "$target_path")"

  if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
    echo "[OK] config link exists: $target_path"
    return
  fi

  if [[ -e "$target_path" || -L "$target_path" ]]; then
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_path="${target_path}.dotfiles-backup-${timestamp}"
    if [[ -e "$backup_path" || -L "$backup_path" ]]; then
      backup_path="${backup_path}-$$"
    fi
    mv "$target_path" "$backup_path"
    echo "[BACKUP] $target_path -> $backup_path"
  fi

  ln -s "$source_path" "$target_path"
  echo "[LINK] $target_path -> $source_path"
}

install_bash() {
  local -a blesh_args
  blesh_args=(--prefix "$BLESH_PREFIX")

  if [[ -n "$BLESH_ARCHIVE" ]]; then
    blesh_args+=(--archive "$BLESH_ARCHIVE")
  fi
  if [[ "$FORCE_BLESH" -eq 1 ]]; then
    blesh_args+=(--force)
  fi

  "$DOTFILES_ROOT/install/bash-ble.sh" "${blesh_args[@]}"
  link_config "$DOTFILES_ROOT/bash/bashrc" "$HOME/.bashrc"

  echo
  echo "Bash config is ready. Start it with: exec bash"
}

install_anaconda() {
  local -a anaconda_args
  anaconda_args=()

  if [[ -n "$ANACONDA_ARCHIVE" ]]; then
    anaconda_args+=(--archive "$ANACONDA_ARCHIVE")
  fi

  "$DOTFILES_ROOT/install/anaconda.sh" "${anaconda_args[@]}"
}

install_zsh() {
  local -a zsh_args
  zsh_args=(--prefix "$ZSH_PREFIX")

  if [[ -n "$ZSH_ARCHIVE" ]]; then
    zsh_args+=(--archive "$ZSH_ARCHIVE")
  fi
  if [[ -n "$NCURSES_ARCHIVE" ]]; then
    zsh_args+=(--ncurses-archive "$NCURSES_ARCHIVE")
  fi
  if [[ "$FORCE_ZSH" -eq 1 ]]; then
    zsh_args+=(--force)
  fi

  "$DOTFILES_ROOT/install/zsh-local.sh" "${zsh_args[@]}"
  "$DOTFILES_ROOT/install/zsh-plugins.sh" --offline-dir "$DOTFILES_ROOT/offline/zsh"
  link_config "$DOTFILES_ROOT/zsh/zshrc" "$HOME/.zshrc"

  echo
  echo "Private zsh is ready: $ZSH_PREFIX/bin/zsh"
  echo "Start it with: exec \"$ZSH_PREFIX/bin/zsh\""
}

install_lazyvim_plugins() (
  set -e

  local nvim_bin="$1"
  local source_lock="$DOTFILES_ROOT/nvim/lazy-lock.json"
  local work_dir install_lock

  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-lazyvim.XXXXXXXX")"
  trap 'rm -rf -- "$work_dir"' EXIT
  install_lock="$work_dir/lazy-lock.json"

  cp "$source_lock" "$install_lock"
  echo "[SYNC] LazyVim plugins"
  DOTFILES_LAZY_INSTALL=1 \
    DOTFILES_LAZY_LOCKFILE="$install_lock" \
    DOTFILES_SOURCE_LOCKFILE="$source_lock" \
    NVIM_LOG_FILE=/dev/null \
    "$nvim_bin" --headless \
    "+lua vim.fn.writefile(vim.fn.readfile(vim.env.DOTFILES_SOURCE_LOCKFILE, 'b'), vim.env.DOTFILES_LAZY_LOCKFILE, 'b'); local lock = require('lazy.manage.lock'); lock._loaded = false; lock.lock = {}" \
    "+lua require('lazy').restore({ wait = true, show = false })" \
    "+lua local missing = {}; for name, plugin in pairs(require('lazy.core.config').plugins) do if plugin._.installed ~= true then missing[#missing + 1] = name end end; if #missing > 0 then table.sort(missing); vim.api.nvim_err_writeln('LazyVim plugins missing: ' .. table.concat(missing, ', ')); vim.cmd('cquit 1') end" \
    +qa </dev/null
)

install_lazyvim() {
  if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: Git is required to install LazyVim plugins." >&2
    exit 1
  fi

  local -a nvim_args
  local nvim_bin="$HOME/.local/bin/nvim"
  nvim_args=()
  if [[ -n "$NVIM_ARCHIVE" ]]; then
    nvim_args+=(--archive "$NVIM_ARCHIVE")
  fi
  if [[ "$FORCE_NVIM" -eq 1 ]]; then
    nvim_args+=(--force)
  fi

  "$DOTFILES_ROOT/install/neovim.sh" "${nvim_args[@]}"
  if ! NVIM_LOG_FILE=/dev/null "$nvim_bin" --clean --headless \
    '+lua if vim.fn.has("nvim-0.11.2") == 0 then vim.cmd("cquit 1") end' \
    +qa >/dev/null 2>&1; then
    echo "ERROR: LazyVim requires Neovim 0.11.2 or newer." >&2
    exit 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "WARNING: LazyVim recommends curl for the completion engine." >&2
  fi

  link_config "$DOTFILES_ROOT/nvim" "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

  install_lazyvim_plugins "$nvim_bin"

  echo
  echo "LazyVim is ready: $nvim_bin"
  echo "Run :LazyHealth inside Neovim to check optional dependencies."
}

if [[ "$INSTALL_ANACONDA" -eq 1 ]]; then
  install_anaconda
fi

if [[ "$INSTALL_BASH" -eq 1 ]]; then
  install_bash
fi

if [[ "$INSTALL_ZSH" -eq 1 ]]; then
  install_zsh
fi

if [[ "$INSTALL_LAZYVIM" -eq 1 ]]; then
  install_lazyvim
fi
