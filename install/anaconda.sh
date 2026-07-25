#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VERSION="2025.12-2"
VERSION="${ANACONDA_VERSION:-$DEFAULT_VERSION}"
PREFIX="$HOME/anaconda3"
ARCHIVE=""

usage() {
  cat <<'EOF'
Usage:
  install/anaconda.sh [--archive FILE]

Installs Anaconda Distribution for the current Linux user without sudo.

Options:
  --archive FILE  Use an existing Anaconda3-*.sh installer
  -h, --help      Show this help

The install location is ~/anaconda3.
Custom versions require both ANACONDA_VERSION and ANACONDA_SHA256.
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
  echo "ERROR: this installer currently supports Linux only." >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64|amd64)
    ARCH="x86_64"
    DEFAULT_SHA256="57b2b48cc5b8665e25fce7011f0389d47c1288288007844b3b1ba482d4f39029"
    ;;
  aarch64|arm64)
    ARCH="aarch64"
    DEFAULT_SHA256="be13a20f31d82508a061984fa3555369cfd8e4692643721415c19e7dc2e9e0f9"
    ;;
  *)
    echo "ERROR: unsupported Linux architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

if [[ "$VERSION" == "$DEFAULT_VERSION" ]]; then
  EXPECTED_SHA256="${ANACONDA_SHA256:-$DEFAULT_SHA256}"
elif [[ -n "${ANACONDA_SHA256:-}" ]]; then
  EXPECTED_SHA256="$ANACONDA_SHA256"
else
  echo "ERROR: set ANACONDA_SHA256 when overriding ANACONDA_VERSION." >&2
  exit 2
fi

if [[ -x "$PREFIX/bin/conda" ]]; then
  INSTALLED_VERSION="$("$PREFIX/bin/conda" --version 2>/dev/null || true)"
  echo "[OK] Anaconda exists: $PREFIX${INSTALLED_VERSION:+ ($INSTALLED_VERSION)}"
  exit 0
fi

if [[ -e "$PREFIX" ]]; then
  echo "ERROR: install path exists but does not contain conda: $PREFIX" >&2
  echo "Move that path aside before installing Anaconda." >&2
  exit 1
fi

if [[ "$VERSION" == "$DEFAULT_VERSION" ]] && command -v getconf >/dev/null 2>&1; then
  GLIBC_INFO="$(getconf GNU_LIBC_VERSION 2>/dev/null || true)"
  if [[ "$GLIBC_INFO" =~ ^glibc[[:space:]]+([0-9]+)\.([0-9]+) ]]; then
    GLIBC_MAJOR="${BASH_REMATCH[1]}"
    GLIBC_MINOR="${BASH_REMATCH[2]}"
    if ((GLIBC_MAJOR < 2 || (GLIBC_MAJOR == 2 && GLIBC_MINOR < 28))); then
      echo "ERROR: Anaconda $VERSION requires glibc 2.28 or newer; found $GLIBC_MAJOR.$GLIBC_MINOR." >&2
      echo "Use an older official installer with ANACONDA_VERSION and ANACONDA_SHA256." >&2
      exit 1
    fi
  fi
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-anaconda.XXXXXXXX")"
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
    echo "ERROR: curl or wget is required to download Anaconda." >&2
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
    echo "ERROR: sha256sum or shasum is required to verify Anaconda." >&2
    exit 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: Anaconda installer SHA-256 mismatch." >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    exit 1
  fi
}

if [[ -n "$ARCHIVE" ]]; then
  if [[ ! -f "$ARCHIVE" ]]; then
    echo "ERROR: Anaconda installer not found: $ARCHIVE" >&2
    exit 1
  fi
  INSTALLER="$ARCHIVE"
else
  INSTALLER="$WORK_DIR/Anaconda3-$VERSION-Linux-$ARCH.sh"
  SOURCE_URL="${ANACONDA_SOURCE_URL:-https://repo.anaconda.com/archive/Anaconda3-$VERSION-Linux-$ARCH.sh}"
  echo "[DOWNLOAD] $SOURCE_URL"
  download "$SOURCE_URL" "$INSTALLER"
fi

verify_sha256 "$INSTALLER" "$EXPECTED_SHA256"

echo "By continuing, you acknowledge the Anaconda legal terms:"
echo "https://www.anaconda.com/legal"
echo "[INSTALL] Anaconda $VERSION -> $PREFIX"
bash "$INSTALLER" -b -p "$PREFIX"

if [[ ! -x "$PREFIX/bin/conda" ]]; then
  echo "ERROR: Anaconda installation verification failed." >&2
  exit 1
fi

echo "[OK] installed Anaconda: $PREFIX ($("$PREFIX/bin/conda" --version))"
echo "Restart Bash/Zsh, or run: source \"$PREFIX/bin/activate\""
