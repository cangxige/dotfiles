#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install/zsh-offline-pack.sh OUT_DIR

Creates an offline zsh dependency directory from the current machine:
  OUT_DIR/oh-my-zsh
  OUT_DIR/plugins/zsh-autosuggestions
  OUT_DIR/plugins/zsh-syntax-highlighting
  OUT_DIR/plugins/z
  OUT_DIR/themes/powerlevel10k

Run install/zsh-plugins.sh first on a networked machine if any dependency is
missing, then copy OUT_DIR and this dotfiles repository to the offline server.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -ne 1 ]]; then
  usage
  [[ $# -eq 1 ]] && exit 0
  exit 2
fi

OUT_DIR="$1"
ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

if [[ -e "$OUT_DIR" ]] && find "$OUT_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  echo "ERROR: output directory is not empty: $OUT_DIR" >&2
  echo "Choose a new directory or empty it explicitly before packing." >&2
  exit 1
fi

require_dir() {
  local dir="$1"
  local label="$2"

  if [[ ! -d "$dir" ]]; then
    echo "ERROR: missing $label: $dir" >&2
    exit 1
  fi
}

plugin_source() {
  local name="$1"

  if [[ -d "$ZSH_CUSTOM/plugins/$name" ]]; then
    printf '%s\n' "$ZSH_CUSTOM/plugins/$name"
  elif [[ -d "$ZSH/plugins/$name" ]]; then
    printf '%s\n' "$ZSH/plugins/$name"
  else
    echo "ERROR: missing plugin $name in $ZSH_CUSTOM/plugins or $ZSH/plugins" >&2
    exit 1
  fi
}

theme_source() {
  local name="$1"

  if [[ -d "$ZSH_CUSTOM/themes/$name" ]]; then
    printf '%s\n' "$ZSH_CUSTOM/themes/$name"
  elif [[ -d "$ZSH/themes/$name" ]]; then
    printf '%s\n' "$ZSH/themes/$name"
  else
    echo "ERROR: missing theme $name in $ZSH_CUSTOM/themes or $ZSH/themes" >&2
    exit 1
  fi
}

copy_dir() {
  local src="$1"
  local dst="$2"

  mkdir -p "$dst"
  tar --exclude-vcs -C "$src" -cf - . | tar -C "$dst" -xf -
}

command -v tar >/dev/null 2>&1 || {
  echo "ERROR: tar is required to create the offline package." >&2
  exit 1
}

require_dir "$ZSH" "oh-my-zsh"
ZSH_AUTOSUGGESTIONS_SRC="$(plugin_source zsh-autosuggestions)"
ZSH_SYNTAX_HIGHLIGHTING_SRC="$(plugin_source zsh-syntax-highlighting)"
Z_SRC="$(plugin_source z)"
POWERLEVEL10K_SRC="$(theme_source powerlevel10k)"

mkdir -p "$OUT_DIR/plugins" "$OUT_DIR/themes"
copy_dir "$ZSH" "$OUT_DIR/oh-my-zsh"
copy_dir "$ZSH_AUTOSUGGESTIONS_SRC" "$OUT_DIR/plugins/zsh-autosuggestions"
copy_dir "$ZSH_SYNTAX_HIGHLIGHTING_SRC" "$OUT_DIR/plugins/zsh-syntax-highlighting"
copy_dir "$Z_SRC" "$OUT_DIR/plugins/z"
copy_dir "$POWERLEVEL10K_SRC" "$OUT_DIR/themes/powerlevel10k"

echo "Offline zsh package created: $OUT_DIR"
echo "On the offline server: install/zsh-plugins.sh --offline-dir $OUT_DIR"
