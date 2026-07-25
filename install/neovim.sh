#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VERSION="0.12.2"
VERSION="${NVIM_VERSION:-$DEFAULT_VERSION}"
PREFIX="$HOME/.local"
ARCHIVE=""
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  install/neovim.sh [--archive FILE] [--force]

Installs the official Neovim Linux tarball under ~/.local without sudo.

Options:
  --archive FILE  Use an existing nvim-linux-*.tar.gz archive
  --force         Reinstall even when this Neovim version already exists
  -h, --help      Show this help

Custom versions require both NVIM_VERSION and NVIM_SHA256.
EOF
}

while (($#)); do
  case "$1" in
    --archive)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --archive requires a file." >&2
        exit 2
      fi
      ARCHIVE="$2"
      shift 2
      ;;
    --force)
      FORCE=1
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

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ERROR: this Neovim installer currently supports Linux only." >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64|amd64)
    ARCH="x86_64"
    DEFAULT_SHA256="31cf85945cb600d96cdf69f88bc68bec814acbff50863c5546adef3a1bcef260"
    ;;
  aarch64|arm64)
    ARCH="arm64"
    DEFAULT_SHA256="f697d4e4582b6e4b5c3c26e76e06ce26efa08ba1768e03fd2733fcc422bb0490"
    ;;
  *)
    echo "ERROR: unsupported Linux architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

if [[ "$VERSION" == "$DEFAULT_VERSION" ]]; then
  EXPECTED_SHA256="${NVIM_SHA256:-$DEFAULT_SHA256}"
elif [[ -n "${NVIM_SHA256:-}" ]]; then
  EXPECTED_SHA256="$NVIM_SHA256"
else
  echo "ERROR: set NVIM_SHA256 when overriding NVIM_VERSION." >&2
  exit 2
fi

version_at_least() {
  local installed="$1"
  local requested="$2"
  local -a installed_parts requested_parts
  local index installed_part requested_part

  IFS=. read -r -a installed_parts <<<"${installed%%-*}"
  IFS=. read -r -a requested_parts <<<"${requested%%-*}"
  for index in 0 1 2; do
    installed_part="${installed_parts[$index]:-0}"
    requested_part="${requested_parts[$index]:-0}"
    ((installed_part > requested_part)) && return 0
    ((installed_part < requested_part)) && return 1
  done
  return 0
}

nvim_version() {
  local binary="$1"
  NVIM_LOG_FILE=/dev/null "$binary" --version 2>/dev/null | sed -n '1s/^NVIM v//p'
}

NVIM_BIN="$PREFIX/bin/nvim"
if [[ "$FORCE" -eq 0 && -x "$NVIM_BIN" ]]; then
  INSTALLED_VERSION="$(nvim_version "$NVIM_BIN")"
  if [[ -n "$INSTALLED_VERSION" ]] && version_at_least "$INSTALLED_VERSION" "$VERSION"; then
    echo "[OK] Neovim $INSTALLED_VERSION exists: $NVIM_BIN"
    exit 0
  fi
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "ERROR: tar is required to install Neovim." >&2
  exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-neovim.XXXXXXXX")"
cleanup() {
  rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT

download() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --retry 3 --output "$output" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget --output-document="$output" "$url"
  else
    echo "ERROR: curl or wget is required to download Neovim." >&2
    exit 1
  fi
}

verify_sha256() {
  local file="$1"
  local expected="$2"
  local actual

  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  else
    echo "ERROR: sha256sum or shasum is required to verify Neovim." >&2
    exit 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: Neovim archive SHA-256 mismatch." >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    exit 1
  fi
}

if [[ -n "$ARCHIVE" ]]; then
  if [[ ! -f "$ARCHIVE" ]]; then
    echo "ERROR: Neovim archive not found: $ARCHIVE" >&2
    exit 1
  fi
  SOURCE_ARCHIVE="$ARCHIVE"
else
  SOURCE_ARCHIVE="$WORK_DIR/nvim-linux-$ARCH.tar.gz"
  SOURCE_URL="${NVIM_SOURCE_URL:-https://github.com/neovim/neovim/releases/download/v$VERSION/nvim-linux-$ARCH.tar.gz}"
  echo "[DOWNLOAD] $SOURCE_URL"
  download "$SOURCE_URL" "$SOURCE_ARCHIVE"
fi

verify_sha256 "$SOURCE_ARCHIVE" "$EXPECTED_SHA256"

mkdir -p "$WORK_DIR/extracted"
tar -xzf "$SOURCE_ARCHIVE" -C "$WORK_DIR/extracted"
SOURCE_DIR="$WORK_DIR/extracted/nvim-linux-$ARCH"
if [[ ! -x "$SOURCE_DIR/bin/nvim" ]]; then
  echo "ERROR: unexpected Neovim archive layout." >&2
  exit 1
fi

EXTRACTED_VERSION="$(nvim_version "$SOURCE_DIR/bin/nvim")"
if [[ "$EXTRACTED_VERSION" != "$VERSION" ]]; then
  echo "ERROR: expected Neovim $VERSION but archive contains $EXTRACTED_VERSION." >&2
  exit 1
fi

INSTALL_DIR="$PREFIX/opt/nvim-$VERSION"
mkdir -p "$PREFIX/opt" "$PREFIX/bin"

if [[ -e "$INSTALL_DIR" ]]; then
  BACKUP_DIR="${INSTALL_DIR}.backup-$(date +%Y%m%d-%H%M%S)-$$"
  mv "$INSTALL_DIR" "$BACKUP_DIR"
  echo "[BACKUP] $INSTALL_DIR -> $BACKUP_DIR"
fi
mv "$SOURCE_DIR" "$INSTALL_DIR"

if [[ -e "$NVIM_BIN" || -L "$NVIM_BIN" ]]; then
  BACKUP_BIN="${NVIM_BIN}.backup-$(date +%Y%m%d-%H%M%S)-$$"
  mv "$NVIM_BIN" "$BACKUP_BIN"
  echo "[BACKUP] $NVIM_BIN -> $BACKUP_BIN"
fi
ln -s "$INSTALL_DIR/bin/nvim" "$NVIM_BIN"

echo "[OK] installed Neovim $VERSION: $NVIM_BIN"
