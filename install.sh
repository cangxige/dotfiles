#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

INSTALL_BASH=0
INSTALL_ZSH=0
INSTALL_LAZYVIM=0
BLESH_ARCHIVE=""
BLESH_PREFIX="${BLESH_PREFIX:-$HOME/.local}"
FORCE_BLESH=0
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
  ./install.sh --lazyvim
  ./install.sh --all [bash and zsh options]

Options:
  --bash                Install ble.sh and link .bashrc
  --zsh                 Build a private zsh, install its plugins, and link .zshrc
  --lazyvim             Link the tracked LazyVim config to ~/.config/nvim
  --all                 Install Bash config, zsh, and LazyVim
  --ble-archive FILE    Install ble.sh from a local archive
  --ble-prefix DIR      Install ble.sh under DIR (default: ~/.local)
  --force-ble           Replace an existing ble.sh installation
  --zsh-archive FILE    Build zsh from a local source archive (for offline hosts)
  --ncurses-archive FILE
                        Use a local ncurses archive if system headers are missing
  --zsh-prefix DIR      Install zsh under DIR (default: ~/.local)
  --force-zsh           Rebuild zsh even when the requested version is installed
  -h, --help            Show this help

Existing config files are moved to a timestamped .dotfiles-backup-* path.
LazyVim plugins are downloaded by Neovim on first launch.
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
    --all)
      INSTALL_BASH=1
      INSTALL_ZSH=1
      INSTALL_LAZYVIM=1
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

if [[ "$INSTALL_BASH" -eq 0 && "$INSTALL_ZSH" -eq 0 && "$INSTALL_LAZYVIM" -eq 0 ]]; then
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

install_lazyvim() {
  if command -v nvim >/dev/null 2>&1; then
    if ! nvim --clean --headless \
      '+lua if vim.fn.has("nvim-0.11.2") == 0 then vim.cmd("cquit 1") end' \
      +qa >/dev/null 2>&1; then
      echo "ERROR: LazyVim requires Neovim 0.11.2 or newer." >&2
      exit 1
    fi
  else
    echo "WARNING: nvim is not installed; install Neovim 0.11.2+ before using LazyVim." >&2
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "WARNING: git is required when LazyVim downloads plugins on first launch." >&2
  fi

  link_config "$DOTFILES_ROOT/nvim" "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

  echo
  echo "LazyVim config is ready. Run nvim to download plugins, then run :LazyHealth."
}

if [[ "$INSTALL_BASH" -eq 1 ]]; then
  install_bash
fi

if [[ "$INSTALL_ZSH" -eq 1 ]]; then
  install_zsh
fi

if [[ "$INSTALL_LAZYVIM" -eq 1 ]]; then
  install_lazyvim
fi
