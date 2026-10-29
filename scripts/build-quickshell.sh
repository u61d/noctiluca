#!/usr/bin/env bash
# builds a private quickshell into ~/.local/opt and leaves the system alone.
#
#   scripts/build-quickshell.sh [--dry-run] [--check-deps] [--jobs N] [--ref TAG]
#
# not the package because other setups ship their own (aur) quickshell builds that conflict
# with it. quickshell uses private qt apis, so rebuild after a qt update; noctiluca-shell
# won't start on a mismatch.
set -euo pipefail

REF="${NOCTILUCA_QS_REF:-v0.3.2}"
REPO="https://github.com/quickshell-mirror/quickshell.git"
PREFIX_BASE="${NOCTILUCA_QS_PREFIX:-$HOME/.local/opt}"
JOBS="$(nproc 2>/dev/null || echo 4)"
DRY=0
CHECK_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --check-deps) CHECK_ONLY=1 ;;
    --jobs) JOBS="${2:?--jobs needs a number}"; shift ;;
    --ref) REF="${2:?--ref needs a tag}"; shift ;;
    -h|--help) sed -n '2,/^set -/ s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) printf 'build-quickshell: unknown argument %s\n' "$1" >&2; exit 64 ;;
  esac
  shift
done

say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf 'build-quickshell: %s\n' "$*" >&2; }
die()  { warn "$*"; exit "${2:-1}"; }
run()  { if [ "$DRY" = 1 ]; then printf '   would run: %s\n' "$*"; else "$@"; fi; }

# "pacman-package:probe-file-or-command"
say "checking build dependencies"
missing=()
need() { # need <pacman package> <test expression...>
  local pkg="$1"; shift
  if ! "$@" >/dev/null 2>&1; then missing+=("$pkg"); fi
}
need base-devel     command -v cc
need cmake          command -v cmake
need ninja          command -v ninja
need git            command -v git
need pkgconf        command -v pkg-config
need qt6-base       pkg-config --exists Qt6Core
need qt6-declarative pkg-config --exists Qt6Quick
need qt6-wayland    pkg-config --exists Qt6WaylandClient
need qt6-shadertools pkg-config --exists Qt6ShaderTools
need wayland        pkg-config --exists wayland-client
need wayland-protocols test -d /usr/share/wayland-protocols
need libdrm         pkg-config --exists libdrm
need pipewire       pkg-config --exists libpipewire-0.3
need pam            test -e /usr/include/security/pam_appl.h
need cli11          test -e /usr/include/CLI/CLI.hpp
need jemalloc       pkg-config --exists jemalloc
need spirv-tools    command -v spirv-opt
need mesa           pkg-config --exists gbm
need vulkan-headers test -e /usr/include/vulkan/vulkan.h
need polkit         pkg-config --exists polkit-agent-1
need glib2          pkg-config --exists glib-2.0

if [ ${#missing[@]} -gt 0 ]; then
  warn "missing build dependencies: ${missing[*]}"
  warn "install them with:"
  warn "    sudo pacman -S --needed ${missing[*]}"
  [ "$CHECK_ONLY" = 1 ] && exit 1
  die "cannot build until these are installed" 69
fi
say "all build dependencies present"

QT_VERSION="$(pkg-config --modversion Qt6Core)"
if ! [ -d "/usr/include/qt6/QtQuick/${QT_VERSION}" ]; then
  warn "Qt private headers for ${QT_VERSION} not found at /usr/include/qt6/QtQuick/${QT_VERSION}"
  warn "The build will likely fail. On Arch they come with qt6-declarative."
fi
say "Qt version: ${QT_VERSION}"
[ "$CHECK_ONLY" = 1 ] && exit 0

SRC="${TMPDIR:-/tmp}/noctiluca-quickshell-${REF}"
PREFIX="${PREFIX_BASE}/quickshell-${REF#v}"

say "source:  ${SRC}"
say "prefix:  ${PREFIX}"
say "ref:     ${REF}"

if [ -d "$SRC/.git" ]; then
  say "reusing existing checkout"
  run git -C "$SRC" fetch --depth 1 origin "$REF"
  run git -C "$SRC" checkout -q FETCH_HEAD
else
  run rm -rf "$SRC"
  run git clone --depth 1 --branch "$REF" "$REPO" "$SRC"
fi

# what the shell doesn't use (checked against CMakeLists.txt at v0.3.2)
CMAKE_ARGS=(
  -GNinja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX="$PREFIX"
  -DDISTRIBUTOR="noctiluca-private"
  -DCRASH_HANDLER=OFF
  -DX11=OFF
  -DI3=OFF
  -DUSE_JEMALLOC=ON
)

say "configuring"
run cmake -S "$SRC" -B "$SRC/build" "${CMAKE_ARGS[@]}"

say "building with ${JOBS} job(s), this takes a while"
run cmake --build "$SRC/build" --parallel "$JOBS"

say "installing to ${PREFIX}"
run cmake --install "$SRC/build"

if [ "$DRY" = 1 ]; then
  printf '   would write: %s/.qt-version (%s)\n' "$PREFIX" "$QT_VERSION"
  printf '   would write: %s/.noctiluca-features (screencopy, polkit, greetd)\n' "$PREFIX"
else
  printf '%s' "$QT_VERSION" > "$PREFIX/.qt-version"
  # so install.sh knows whether to offer a rebuild
  printf 'screencopy\npolkit\ngreetd\n' > "$PREFIX/.noctiluca-features"
fi

if [ "$DRY" = 1 ]; then
  say "dry run complete, nothing was changed"
  exit 0
fi

BIN="$PREFIX/bin/qs"
[ -x "$BIN" ] || die "build finished but $BIN is missing" 70
say "installed: $($BIN --version 2>&1 | head -n1)"
say "Qt stamp:  $(cat "$PREFIX/.qt-version")"
say "done. \`noctiluca-shell\` will pick this up automatically."
