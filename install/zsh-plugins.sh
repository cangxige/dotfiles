#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install/zsh-plugins.sh [--offline-dir DIR] [--online-only]

Installs oh-my-zsh, zsh plugins, and the powerlevel10k theme.

Offline directory layout:
  DIR/oh-my-zsh
  DIR/plugins/zsh-autosuggestions
  DIR/plugins/zsh-syntax-highlighting
  DIR/plugins/z
  DIR/themes/powerlevel10k

You can create that directory with install/zsh-offline-pack.sh on a machine
where the dependencies are already installed.
EOF
}

OFFLINE_DIR="${ZSH_OFFLINE_DIR:-}"
ONLINE_ONLY=0

while (($#)); do
  case "$1" in
    --offline-dir)
      OFFLINE_DIR="${2:-}"
      if [[ -z "$OFFLINE_DIR" ]]; then
        echo "ERROR: --offline-dir requires a directory." >&2
        exit 2
      fi
      shift 2
      ;;
    --online-only)
      ONLINE_ONLY=1
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

if [[ -n "$OFFLINE_DIR" ]]; then
  if [[ ! -d "$OFFLINE_DIR" ]]; then
    echo "ERROR: offline directory not found: $OFFLINE_DIR" >&2
    exit 1
  fi
  OFFLINE_DIR="$(cd "$OFFLINE_DIR" && pwd)"
fi

ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

copy_dir() {
  local src="$1"
  local dst="$2"

  if [[ ! -d "$src" ]]; then
    echo "ERROR: offline source not found: $src" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
}

clone_repo() {
  local repo="$1"
  local dst="$2"

  if [[ -n "$OFFLINE_DIR" && "$ONLINE_ONLY" -eq 0 ]]; then
    echo "ERROR: offline package is missing a required component for $dst" >&2
    exit 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is unavailable. Use --offline-dir DIR instead." >&2
    exit 1
  fi

  git clone --depth 1 "$repo" "$dst"
}

install_oh_my_zsh() {
  if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
    echo "[OK] oh-my-zsh exists: $ZSH"
  elif [[ -n "$OFFLINE_DIR" && "$ONLINE_ONLY" -eq 0 ]]; then
    echo "[COPY] oh-my-zsh"
    copy_dir "$OFFLINE_DIR/oh-my-zsh" "$ZSH"
  else
    echo "[INSTALL] oh-my-zsh"
    clone_repo https://github.com/ohmyzsh/ohmyzsh.git "$ZSH"
  fi
}

install_plugin() {
  local name="$1"
  local repo="$2"
  local dir="$ZSH_CUSTOM/plugins/$name"
  local offline_src="$OFFLINE_DIR/plugins/$name"

  if [[ -d "$dir" ]]; then
    echo "[OK] plugin exists: $name"
  elif [[ -n "$OFFLINE_DIR" && "$ONLINE_ONLY" -eq 0 ]]; then
    echo "[COPY] plugin $name"
    copy_dir "$offline_src" "$dir"
  else
    echo "[INSTALL] $name"
    clone_repo "$repo" "$dir"
  fi
}

install_theme() {
  local name="$1"
  local repo="$2"
  local dir="$ZSH_CUSTOM/themes/$name"
  local offline_src="$OFFLINE_DIR/themes/$name"

  if [[ -d "$dir" ]]; then
    echo "[OK] theme exists: $name"
  elif [[ -n "$OFFLINE_DIR" && "$ONLINE_ONLY" -eq 0 ]]; then
    echo "[COPY] theme $name"
    copy_dir "$offline_src" "$dir"
  else
    echo "[INSTALL] theme $name"
    clone_repo "$repo" "$dir"
  fi
}

install_oh_my_zsh
install_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
install_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
install_plugin z https://github.com/agkozak/zsh-z

# powerlevel10k theme folder name must match "powerlevel10k"
install_theme powerlevel10k https://github.com/romkatv/powerlevel10k.git

echo "Done. Restart zsh or run: exec zsh"
