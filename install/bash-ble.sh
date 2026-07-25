#!/usr/bin/env bash
set -euo pipefail

VERSION="${BLESH_VERSION:-0.4.0-devel3}"
EXPECTED_SHA256="${BLESH_SHA256:-c8612ee612bc6b10dbfd6e85c6cbdfd7caf152a12d1f9de22ea0a9d735b3080c}"
PREFIX="${BLESH_PREFIX:-$HOME/.local}"
ARCHIVE=""
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  install/bash-ble.sh [--prefix DIR] [--archive FILE] [--force]

Installs ble.sh without root privileges.

Options:
  --prefix DIR    Installation prefix (default: ~/.local)
  --archive FILE  Use an existing ble-*.tar.xz archive
  --force         Replace an existing ble.sh installation
  -h, --help      Show this help
EOF
}

while (($#)); do
  case "$1" in
    --prefix)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --prefix requires a directory." >&2
        exit 2
      fi
      PREFIX="$2"
      shift 2
      ;;
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

BLESH_DIR="$PREFIX/share/blesh"
if [[ -r "$BLESH_DIR/ble.sh" && "$FORCE" -eq 0 ]]; then
  echo "[OK] ble.sh exists: $BLESH_DIR/ble.sh"
  exit 0
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "ERROR: tar is required to install ble.sh." >&2
  exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-blesh.XXXXXXXX")"
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
    echo "ERROR: curl or wget is required to download ble.sh." >&2
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
    echo "ERROR: sha256sum or shasum is required to verify ble.sh." >&2
    exit 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: ble.sh archive SHA-256 mismatch." >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    exit 1
  fi
}

SOURCE_ARCHIVE="$WORK_DIR/ble-$VERSION.tar.xz"
if [[ -n "$ARCHIVE" ]]; then
  if [[ ! -f "$ARCHIVE" ]]; then
    echo "ERROR: ble.sh archive not found: $ARCHIVE" >&2
    exit 1
  fi
  cp "$ARCHIVE" "$SOURCE_ARCHIVE"
else
  SOURCE_URL="${BLESH_SOURCE_URL:-https://github.com/akinomyoga/ble.sh/releases/download/v$VERSION/ble-$VERSION.tar.xz}"
  echo "[DOWNLOAD] $SOURCE_URL"
  download "$SOURCE_URL" "$SOURCE_ARCHIVE"
fi

verify_sha256 "$SOURCE_ARCHIVE" "$EXPECTED_SHA256"

mkdir -p "$WORK_DIR/extracted"
tar -xJf "$SOURCE_ARCHIVE" -C "$WORK_DIR/extracted"
SOURCE_DIR="$WORK_DIR/extracted/ble-$VERSION"
if [[ ! -r "$SOURCE_DIR/ble.sh" ]]; then
  echo "ERROR: unexpected ble.sh archive layout." >&2
  exit 1
fi

mkdir -p "$(dirname "$BLESH_DIR")"
if [[ -e "$BLESH_DIR" ]]; then
  BACKUP_DIR="${BLESH_DIR}.backup-$(date +%Y%m%d-%H%M%S)"
  mv "$BLESH_DIR" "$BACKUP_DIR"
  echo "[BACKUP] $BLESH_DIR -> $BACKUP_DIR"
fi
mv "$SOURCE_DIR" "$BLESH_DIR"

echo "[OK] installed ble.sh $VERSION: $BLESH_DIR/ble.sh"
