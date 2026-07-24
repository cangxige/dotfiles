#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VERSION="5.9.2"
DEFAULT_SHA256="36fa734374b44783582cec09bcd67822e2f992c779ec1624ab5596df078d2f81"
NCURSES_VERSION="6.6"
NCURSES_SHA256="355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11"

VERSION="${ZSH_VERSION:-$DEFAULT_VERSION}"
PREFIX="${ZSH_PREFIX:-$HOME/.local}"
ARCHIVE=""
NCURSES_ARCHIVE=""
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  install/zsh-local.sh [--prefix DIR] [--archive FILE]
                       [--ncurses-archive FILE] [--force]

Downloads the official zsh source, verifies it, and installs zsh without root.

Options:
  --prefix DIR    Installation prefix (default: ~/.local)
  --archive FILE  Use an existing zsh-*.tar.xz archive instead of downloading
  --ncurses-archive FILE
                  Use an existing ncurses-*.tar.gz if system headers are missing
  --force         Rebuild even when the requested version is already installed
  -h, --help      Show this help

Environment overrides:
  ZSH_VERSION       Source version (default: 5.9.2)
  ZSH_SOURCE_URL    Source archive URL
  ZSH_SHA256        Expected SHA-256 (required for a non-default version)
  ZSH_BUILD_JOBS    Parallel make jobs
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
    --ncurses-archive)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --ncurses-archive requires a file." >&2
        exit 2
      fi
      NCURSES_ARCHIVE="$2"
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

if [[ -n "${ZSH_SHA256:-}" ]]; then
  EXPECTED_SHA256="$ZSH_SHA256"
elif [[ "$VERSION" == "$DEFAULT_VERSION" ]]; then
  EXPECTED_SHA256="$DEFAULT_SHA256"
else
  echo "ERROR: set ZSH_SHA256 when overriding ZSH_VERSION." >&2
  exit 2
fi

ZSH_BIN="$PREFIX/bin/zsh"
if [[ "$FORCE" -eq 0 && -x "$ZSH_BIN" ]]; then
  # shellcheck disable=SC2016 # Expanded by the zsh child process.
  INSTALLED_VERSION="$("$ZSH_BIN" -fc 'print -r -- "$ZSH_VERSION"' 2>/dev/null || true)"
  if [[ "$INSTALLED_VERSION" == "$VERSION" ]]; then
    echo "[OK] zsh $VERSION exists: $ZSH_BIN"
    exit 0
  fi
fi

for tool in make tar xz; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: $tool is required to build zsh." >&2
    exit 1
  fi
done

if ! command -v "${CC:-cc}" >/dev/null 2>&1; then
  echo "ERROR: a C compiler is required to build zsh (set CC if needed)." >&2
  exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-zsh.XXXXXXXX")"
cleanup() {
  if [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]]; then
    rm -rf -- "$WORK_DIR"
  fi
}
trap cleanup EXIT

download_file() {
  local url="$1"
  local output="$2"

  echo "[DOWNLOAD] $url"
  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --retry 3 --output "$output" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget --output-document="$output" "$url"
  else
    echo "ERROR: curl or wget is required; alternatively provide local archives." >&2
    exit 1
  fi
}

verify_sha256() {
  local file="$1"
  local expected="$2"
  local label="$3"
  local actual

  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  else
    echo "ERROR: sha256sum or shasum is required to verify sources." >&2
    exit 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: $label checksum mismatch." >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    exit 1
  fi
  echo "[OK] $label checksum verified"
}

SOURCE_ARCHIVE="$WORK_DIR/zsh-$VERSION.tar.xz"
if [[ -n "$ARCHIVE" ]]; then
  if [[ ! -f "$ARCHIVE" ]]; then
    echo "ERROR: zsh source archive not found: $ARCHIVE" >&2
    exit 1
  fi
  cp "$ARCHIVE" "$SOURCE_ARCHIVE"
else
  SOURCE_URL="${ZSH_SOURCE_URL:-https://www.zsh.org/pub/zsh-$VERSION.tar.xz}"
  download_file "$SOURCE_URL" "$SOURCE_ARCHIVE"
fi

verify_sha256 "$SOURCE_ARCHIVE" "$EXPECTED_SHA256" "zsh source"

tar -xJf "$SOURCE_ARCHIVE" -C "$WORK_DIR"
SOURCE_DIR="$WORK_DIR/zsh-$VERSION"
if [[ ! -x "$SOURCE_DIR/configure" ]]; then
  echo "ERROR: unexpected zsh archive layout." >&2
  exit 1
fi

if [[ -n "${ZSH_BUILD_JOBS:-}" ]]; then
  BUILD_JOBS="$ZSH_BUILD_JOBS"
elif command -v getconf >/dev/null 2>&1; then
  BUILD_JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')"
else
  BUILD_JOBS=1
fi

ZSH_CPPFLAGS="${CPPFLAGS:-}"
ZSH_LDFLAGS="${LDFLAGS:-}"
if ! printf '#include <ncurses.h>\n' | "${CC:-cc}" -E - >/dev/null 2>&1 &&
   ! printf '#include <ncurses/ncurses.h>\n' | "${CC:-cc}" -E - >/dev/null 2>&1 &&
   ! printf '#include <ncursesw/ncurses.h>\n' | "${CC:-cc}" -E - >/dev/null 2>&1 &&
   ! printf '#include <termcap.h>\n' | "${CC:-cc}" -E - >/dev/null 2>&1; then
  NCURSES_SOURCE_ARCHIVE="$WORK_DIR/ncurses-$NCURSES_VERSION.tar.gz"
  if [[ -n "$NCURSES_ARCHIVE" ]]; then
    if [[ ! -f "$NCURSES_ARCHIVE" ]]; then
      echo "ERROR: ncurses source archive not found: $NCURSES_ARCHIVE" >&2
      exit 1
    fi
    cp "$NCURSES_ARCHIVE" "$NCURSES_SOURCE_ARCHIVE"
  else
    download_file \
      "https://ftp.gnu.org/gnu/ncurses/ncurses-$NCURSES_VERSION.tar.gz" \
      "$NCURSES_SOURCE_ARCHIVE"
  fi
  verify_sha256 "$NCURSES_SOURCE_ARCHIVE" "$NCURSES_SHA256" "ncurses source"

  tar -xzf "$NCURSES_SOURCE_ARCHIVE" -C "$WORK_DIR"
  echo "[BUILD] private ncurses $NCURSES_VERSION (system development headers not found)"
  (
    cd "$WORK_DIR/ncurses-$NCURSES_VERSION"
    ./configure \
      --prefix="$PREFIX" \
      --with-shared \
      --with-termlib \
      --without-ada \
      --without-cxx \
      --without-debug \
      --without-normal \
      --without-tests
    make -j"$BUILD_JOBS"
    make install
  )

  ZSH_CPPFLAGS="$ZSH_CPPFLAGS -I$PREFIX/include"
  ZSH_LDFLAGS="$ZSH_LDFLAGS -L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
fi

echo "[BUILD] zsh $VERSION"
(
  cd "$SOURCE_DIR"
  CPPFLAGS="$ZSH_CPPFLAGS" LDFLAGS="$ZSH_LDFLAGS" \
    ./configure --prefix="$PREFIX" --enable-multibyte
  make -j"$BUILD_JOBS"
  make install
)

# shellcheck disable=SC2016 # Expanded by the zsh child process.
INSTALLED_VERSION="$("$ZSH_BIN" -fc 'print -r -- "$ZSH_VERSION"')"
if [[ "$INSTALLED_VERSION" != "$VERSION" ]]; then
  echo "ERROR: installed zsh failed version verification." >&2
  exit 1
fi

echo "[OK] installed zsh $VERSION: $ZSH_BIN"
