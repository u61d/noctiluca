#!/usr/bin/env bash
# noctiluca as your login screen, through greetd.
#
#   scripts/install-greeter.sh [--refresh | --dry-run | --uninstall]
#
# greetd runs the greeter as its own user, which can't read your home, so the shell, palette,
# wallpaper and face get copied to /usr/share/noctiluca/greeter. run --refresh after changing
# your wallpaper or updating. the old greetd config is kept as config.toml.noctiluca-backup.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="/usr/share/noctiluca/greeter"
BIN="/usr/local/lib/noctiluca/quickshell"
GREETD="/etc/greetd/config.toml"
BACKUP="$GREETD.noctiluca-backup"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/noctiluca"

DRY=0
MODE=install
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --refresh) MODE=refresh ;;
    --uninstall) MODE=uninstall ;;
    -h|--help) sed -n '2,/^set -/ s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) printf 'install-greeter: unknown argument %s\n' "$a" >&2; exit 64 ;;
  esac
done

say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf 'install-greeter: %s\n' "$*" >&2; exit "${2:-1}"; }
run()  { if [ "$DRY" = 1 ]; then printf '   would run: %s\n' "$*"; else "$@"; fi; }
ask()  { [ "$DRY" = 1 ] && return 0; local r; read -r -p "    $* [y/N] " r; [[ "$r" =~ ^[Yy] ]]; }

if [ "$MODE" = uninstall ]; then
  say "removing the NOCTILUCA login screen"
  if [ -f "$BACKUP" ]; then
    run sudo mv "$BACKUP" "$GREETD"
    info "your previous greetd config is back; greetd stays on with it"
  elif [ -f "$GREETD" ] && grep -q "$DEST" "$GREETD"; then
    # no greetd config before ours means greetd wasn't your login, so turn it off again
    run sudo rm -f "$GREETD"
    if systemctl is-enabled greetd >/dev/null 2>&1; then
      run sudo systemctl disable greetd
      info "greetd is off again (it had no config of its own before NOCTILUCA's)"
    fi
    info "to use another login screen, enable it, e.g.: sudo systemctl enable sddm"
    info "with none enabled you log in on the console, as before"
  fi
  run sudo rm -rf "$DEST" "$(dirname "$BIN")"
  exit 0
fi

say "checking"
qs="$("$ROOT/scripts/noctiluca-shell" --print-qs 2>/dev/null || true)"
[ -n "$qs" ] || die "no Quickshell build found; run ./install.sh first"
prefix="$(dirname "$(dirname "$qs")")"
real="$(readlink -f "$qs")"
grep -qx greetd "$prefix/.noctiluca-features" 2>/dev/null \
  || die "your Quickshell build has no greetd support; rebuild it: ./install.sh --build"
info "Quickshell: $real"

if ! pacman -Qi greetd >/dev/null 2>&1; then
  info "greetd isn't installed"
  if ask "install it now? (sudo pacman -S --needed greetd)"; then
    run sudo pacman -S --needed greetd
  else
    die "the login screen needs greetd"
  fi
fi
command -v Hyprland >/dev/null || die "Hyprland isn't installed"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
say "putting the greeter together"

cp -r "$ROOT/shell/." "$stage/"
cp "$ROOT/greeter/shell.qml" "$stage/shell.qml"
cp "$ROOT/greeter/hyprland.lua" "$stage/hyprland.lua"

printf '{ "user": "%s", "session": "Hyprland" }\n' "$USER" > "$stage/greeter.json"

mkdir -p "$stage/state/noctiluca" "$stage/faces"
[ -f "$STATE/palette.json" ] && cp "$STATE/palette.json" "$stage/state/noctiluca/palette.json"
if [ -f "$STATE/wallpaper" ]; then
  wall="$(cat "$STATE/wallpaper")"
  if [ -f "$wall" ]; then
    ext="${wall##*.}"
    cp "$wall" "$stage/state/noctiluca/wallpaper.$ext"
    printf '%s\n' "$DEST/state/noctiluca/wallpaper.$ext" > "$stage/state/noctiluca/wallpaper"
  fi
fi
[ -f "$HOME/.face" ] && cp "$HOME/.face" "$stage/faces/$USER"

# your keyboard layout, so the password types the way you type it
layout="us"; variant=""; options=""
if command -v hyprctl >/dev/null && hyprctl devices -j >/dev/null 2>&1 && command -v jq >/dev/null; then
  kb="$(hyprctl devices -j | jq -r '(.keyboards | map(select(.main)) | .[0]) // .keyboards[0] | [.layout, .variant, .options] | @tsv' 2>/dev/null || true)"
  if [ -n "$kb" ]; then IFS=$'\t' read -r layout variant options <<<"$kb"; fi
fi
lua_str() { printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }
nvidia_env=""
if [ -e /sys/module/nvidia_drm ]; then
  nvidia_env='  LIBVA_DRIVER_NAME = "nvidia", __GLX_VENDOR_LIBRARY_NAME = "nvidia", GBM_BACKEND = "nvidia-drm",'
fi
cat > "$stage/greeter-local.lua" <<EOF
-- written by install-greeter.sh from your session; run it with --refresh after changing these
return {
  kb_layout = $(lua_str "$layout"),
  kb_variant = $(lua_str "$variant"),
  kb_options = $(lua_str "$options"),
  env = {
$nvidia_env
  },
}
EOF
info "keyboard: $layout${variant:+ ($variant)}"

say "installing (sudo)"
run sudo install -Dm755 "$real" "$BIN"
[ -f "$prefix/.qt-version" ] && run sudo install -Dm644 "$prefix/.qt-version" "$(dirname "$BIN")/.qt-version"
run sudo rm -rf "$DEST"
run sudo install -d "$DEST"
run sudo cp -r "$stage/." "$DEST/"
run sudo chmod -R a+rX "$DEST"
info "greeter: $DEST"

if [ "$MODE" = refresh ]; then
  say "refreshed. It shows from the next login screen on."
  exit 0
fi

say "greetd"
if [ -f "$GREETD" ] && [ ! -f "$BACKUP" ] && ! grep -q "$DEST" "$GREETD"; then
  run sudo cp "$GREETD" "$BACKUP"
  info "your current config is kept as $BACKUP"
fi
greeter_user="greeter"
id greeter >/dev/null 2>&1 || greeter_user="$(sed -n 's/^user *= *"\(.*\)"/\1/p' "$GREETD" 2>/dev/null | head -n1)"
conf="$(mktemp)"
cat > "$conf" <<EOF
# written by noctiluca's install-greeter.sh. the old config is $BACKUP
[terminal]
vt = 1

[default_session]
command = "Hyprland --config $DEST/hyprland.lua"
user = "${greeter_user:-greeter}"
EOF
run sudo install -Dm644 "$conf" "$GREETD"
rm -f "$conf"

current_dm="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)"
if [ -n "$current_dm" ] && [ "$(basename "$current_dm")" != "greetd.service" ]; then
  info "$(basename "$current_dm") is your display manager now. To switch:"
  info "  sudo systemctl disable $(basename "$current_dm") && sudo systemctl enable greetd"
elif systemctl is-enabled greetd >/dev/null 2>&1; then
  info "greetd is already enabled"
elif ask "enable greetd, so the login screen shows from the next boot?"; then
  run sudo systemctl enable greetd
fi

say "done"
info "Keep a TTY you can switch to the first time (Ctrl+Alt+F2). To undo: $0 --uninstall"
