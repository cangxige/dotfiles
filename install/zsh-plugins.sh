#!/usr/bin/env bash
set -euo pipefail

# Ensure oh-my-zsh exists
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "ERROR: ~/.oh-my-zsh not found. Install oh-my-zsh first." >&2
  exit 1
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

install_plugin () {
  local name="$1"
  local repo="$2"
  local dir="$ZSH_CUSTOM/plugins/$name"

  if [ -d "$dir/.git" ]; then
    echo "[OK] plugin exists: $name"
  else
    echo "[INSTALL] $name"
    git clone --depth 1 "$repo" "$dir"
  fi
}

install_theme () {
  local name="$1"
  local repo="$2"
  local dir="$ZSH_CUSTOM/themes/$name"

  if [ -d "$dir/.git" ]; then
    echo "[OK] theme exists: $name"
  else
    echo "[INSTALL] theme $name"
    git clone --depth 1 "$repo" "$dir"
  fi
}

install_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
install_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
install_plugin z https://github.com/agkozak/zsh-z

# powerlevel10k theme folder name must match "powerlevel10k"
install_theme powerlevel10k https://github.com/romkatv/powerlevel10k.git

echo "Done. Restart zsh or run: exec zsh"
