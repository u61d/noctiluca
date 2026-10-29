#!/usr/bin/env bash
# usage: ./install.sh [options]
#   --dry-run          show what it would do, change nothing
#   --yes              don't ask
#   --packages | --build | --links | --theme   only that step
#   --uninstall        remove the links, put backups back
#   --list-packages    what gets installed and why
#
# safe to run twice. anything of yours in the way gets moved to
# ~/.local/state/noctiluca/backups/ first (after asking). arch only.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/noctiluca"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN="$HOME/.local/bin"
BACKUP="$STATE/backups/$(date +%Y%m%d-%H%M%S)"
MANIFEST="$STATE/installed-links"

DRY=0
ASSUME_YES=0
DO_PACKAGES=0; DO_BUILD=0; DO_LINKS=0; DO_THEME=0; DO_UNINSTALL=0
EXPLICIT=0

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
say()   { printf '\033[1m==>\033[0m %s\n' "$*"; }
info()  { printf '    %s\n' "$*"; }
good()  { printf '    \033[32mok\033[0m       %s\n' "$*"; }
skipd() { printf '    \033[2mskip\033[0m     %s\n' "$*"; }
chng()  { printf '    \033[36m%s\033[0m %s\n' "$(printf '%-8s' "$1")" "$2"; }
warn()  { printf 'install: %s\n' "$*" >&2; }
die()   { warn "$*"; exit "${2:-1}"; }

run() {
  if [ "$DRY" = 1 ]; then printf '    \033[2mwould run:\033[0m %s\n' "$*"; return 0; fi
  "$@"
}

# no tty means no, so an unattended run never moves your files
ask() {
  [ "$ASSUME_YES" = 1 ] && return 0
  [ "$DRY" = 1 ] && return 0
  if [ ! -t 0 ]; then
    warn "not a terminal and --yes was not given; refusing: $1"
    return 1
  fi
  local reply
  printf '    %s [y/N] ' "$1"
  read -r reply || return 1
  case "$reply" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --packages) DO_PACKAGES=1; EXPLICIT=1 ;;
    --build) DO_BUILD=1; EXPLICIT=1 ;;
    --links) DO_LINKS=1; EXPLICIT=1 ;;
    --theme) DO_THEME=1; EXPLICIT=1 ;;
    --uninstall) DO_UNINSTALL=1; EXPLICIT=1 ;;
    --list-packages) LIST_ONLY=1; EXPLICIT=1 ;;
    -h|--help) sed -n '2,/^set -/ s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) die "unknown argument: $1  (try --help)" 64 ;;
  esac
  shift
done
if [ "$EXPLICIT" = 0 ]; then DO_PACKAGES=1; DO_BUILD=1; DO_LINKS=1; DO_THEME=1; fi

# name|group|why (--list-packages prints these)
PACKAGES=(
  "hyprland|compositor|the compositor itself (0.56+ for the Lua config)"
  "lua|compositor|Hyprland 0.56 reads hyprland.lua with Lua 5.5"
  "hypridle|compositor|locks the screen before suspend (timeouts are in the shell)"
  "xdg-desktop-portal-hyprland|compositor|screen sharing and the Wayland portal"
  "xdg-desktop-portal-gtk|compositor|the file chooser every GTK app opens"

  "base-devel|build|compiler toolchain"
  "git|build|fetching the v0.3.2 tag"
  "cmake|build|build system"
  "ninja|build|the only generator upstream tests"
  "pkgconf|build|pkg-config, used to find Qt"
  "qt6-base|build|Quickshell links against Qt 6 and its private headers"
  "qt6-declarative|build|QtQuick, and the private QML headers Quickshell needs"
  "qt6-shadertools|build|build-time shader compilation"
  "spirv-tools|build|build-time, with qt6-shadertools"
  "cli11|build|Quickshell's command line parser"
  "libdrm|build|required dependency"
  "wayland|build|libwayland"
  "wayland-protocols|build|the protocol XML, including ext-session-lock"
  "pipewire|build|libpipewire, for the audio service"
  "pam|build|libpam, for the lockscreen"
  "jemalloc|build|upstream recommends it: avoids an apparent QML memory leak"
  "mesa|build|libgbm, for screencopy (the overview's live window previews)"
  "vulkan-headers|build|build-time, for screencopy"
  "polkit|build|polkit-agent-1, for the password prompt apps ask for"

  "grim|runtime|screenshots"
  "brightnessctl|runtime|brightness keys on laptops"
  "qt6-wayland|runtime|without it Quickshell cannot open a window at all"
  "qt6-svg|runtime|SVG images fail silently without it"
  "breeze-icons|look|icons for Qt and KDE apps like Dolphin"
  "qt6ct|runtime|applies the generated Qt palette"
  "kvantum|runtime|Qt widget theme engine; we generate a theme for it"
  "networkmanager|runtime|the ONLY backend Quickshell's network module has"
  "bluez|runtime|the Bluetooth tile talks to BlueZ"
  "bluez-utils|runtime|bluetoothctl, and the BlueZ D-Bus interfaces"
  "power-profiles-daemon|runtime|backs the power-profile tile"
  "pipewire-pulse|runtime|PulseAudio compatibility for apps"
  "wireplumber|runtime|the PipeWire session manager"
  "cliphist|runtime|clipboard history for the launcher"
  "wl-clipboard|runtime|wl-copy / wl-paste, which cliphist drives"
  "libnotify|runtime|notify-send, for testing the notification daemon"
  "cava|runtime|the audio visualiser in the player card"
  "curl|runtime|fetches synced lyrics from lrclib"
  "jq|runtime|used by the scripts"
  "hyprsunset|runtime|night light"
  "hyprpicker|runtime|the colour picker"
  "gpu-screen-recorder|runtime|screen recording (NVENC / VA-API)"
  "fd|runtime|file search in the launcher"
  "noto-fonts-emoji|runtime|the emoji picker"

  "ttf-ibm-plex|look|IBM Plex Sans and Mono: the only two fonts in the design"
  "adw-gtk-theme|look|GTK3 base whose named colours we override"

  "python|tools|the palette engine and the theme renderer"
  "python-pillow|tools|reads the wallpaper to extract its hue"

  "kitty|session|terminal; themed by the palette"
  "zsh|session|shell; the prompt is themed too"
  "fastfetch|session|system info, styled by us"
  "zsh-autosuggestions|session|greyed-out suggestions from your history as you type"
  "zsh-syntax-highlighting|session|colours the command line as you type it"
  "eza|session|ls with icons and git status; ls/ll/la/lt use it"
  "ttf-nerd-fonts-symbols-mono|session|the icons in the prompt, eza and fastfetch (Plex stays Plex)"

  "shellcheck|dev|checks the shell scripts"
  "glslang|dev|compiles the screen shader as a test"
)

# the repo quickshell would replace whatever quickshell build is already here
CONFLICTS=(
  "quickshell|conflicts with the AUR quickshell builds other setups use; NOCTILUCA builds its own copy under \$HOME instead"
  "waybar|the shell draws its own bar"
  "eww|the shell draws its own widgets"
  "rofi|the shell has its own launcher"
  "dunst|the shell is the notification daemon"
  "mako|the shell is the notification daemon"
  "swaync|the shell is the notification daemon"
  "wlogout|the shell has its own power menu"
  "hyprlock|the shell has its own lockscreen"
  "hyprpaper|the shell draws the wallpaper"
  "swww|the shell draws the wallpaper"
  "hyprpolkitagent|the shell is the polkit agent; only one can run"
  "polkit-gnome|the shell is the polkit agent; only one can run"
)

list_packages() {
  local group="" last=""
  for entry in "${PACKAGES[@]}"; do
    IFS='|' read -r name group reason <<<"$entry"
    [ "$group" != "$last" ] && { printf '\n  \033[1m%s\033[0m\n' "$group"; last="$group"; }
    printf '    %-28s %s\n' "$name" "$reason"
  done
  printf '\n  \033[1mdeliberately NOT installed\033[0m\n'
  for entry in "${CONFLICTS[@]}"; do
    IFS='|' read -r name reason <<<"$entry"
    printf '    %-28s %s\n' "$name" "$reason"
  done
  printf '\n'
}

if [ "${LIST_ONLY:-0}" = 1 ]; then list_packages; exit 0; fi

# target|source, target is under $HOME
links() {
  cat <<EOF
$CONFIG/hypr|$ROOT/config/hypr
$CONFIG/quickshell/noctiluca|$ROOT/shell
$CONFIG/kitty/kitty.conf|$ROOT/config/kitty/kitty.conf
$CONFIG/noctiluca/prompt.zsh|$ROOT/config/zsh/noctiluca.zsh
$BIN/noctiluca-palette|$ROOT/scripts/noctiluca-palette
$BIN/noctiluca-theme|$ROOT/scripts/noctiluca-theme
$BIN/noctiluca-shell|$ROOT/scripts/noctiluca-shell
$BIN/noctiluca-ctl|$ROOT/scripts/noctiluca-ctl
$BIN/noctiluca-wallpaper|$ROOT/scripts/noctiluca-wallpaper
$DATA/dbus-1/services/org.freedesktop.Notifications.service|$ROOT/config/dbus/org.freedesktop.Notifications.service
EOF
}

bold "NOCTILUCA"
[ "$DRY" = 1 ] && info "dry run: nothing will be changed"

[ "$(id -u)" = 0 ] && die "do not run this as root. It installs into your home; it will use sudo for pacman only."
[ -f "$ROOT/shell/shell.qml" ] || die "run this from the NOCTILUCA repo (no shell/shell.qml next to install.sh)"

if [ "$DO_UNINSTALL" = 0 ] && [ "$DO_PACKAGES" = 1 ]; then
  command -v pacman >/dev/null 2>&1 || die "pacman not found: this installer is for Arch Linux." 70
fi

if [ "$DO_UNINSTALL" = 1 ]; then
  say "removing the links this installer made"
  if [ ! -f "$MANIFEST" ]; then
    info "no manifest at $MANIFEST; nothing recorded as installed"
  else
    while IFS= read -r target; do
      [ -n "$target" ] || continue
      if [ -L "$target" ]; then
        chng "remove" "$target"
        run rm -f "$target"
      else
        skipd "$target (not a symlink any more; left alone)"
      fi
    done < "$MANIFEST"
    run rm -f "$MANIFEST"
  fi
  latest="$(find "$STATE/backups" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -n1)"
  if [ -n "$latest" ]; then
    info "your originals are still in $latest; restore anything you want by hand"
  fi
  info "packages and the private Quickshell build were NOT removed."
  info "  rm -rf ~/.local/opt/quickshell-*   removes the build"
  exit 0
fi

if [ "$DO_PACKAGES" = 1 ]; then
  say "packages"

  blocked=()
  for entry in "${CONFLICTS[@]}"; do
    IFS='|' read -r name reason <<<"$entry"
    if pacman -Qq "$name" >/dev/null 2>&1; then blocked+=("$name: $reason"); fi
  done
  if [ "${#blocked[@]}" -gt 0 ]; then
    warn "these are installed and will get in the way:"
    for b in "${blocked[@]}"; do warn "  $b"; done
    warn "NOCTILUCA does not remove them, since removing a package affects every user on the machine."
    warn "Stop any of them that start at login (see docs/PACKAGES.md)."
  fi

  want=(); already=(); unknown=()
  for entry in "${PACKAGES[@]}"; do
    IFS='|' read -r name _ _ <<<"$entry"
    if pacman -Qq "$name" >/dev/null 2>&1; then
      already+=("$name")
    elif pacman -Si "$name" >/dev/null 2>&1; then
      want+=("$name")
    else
      unknown+=("$name")
    fi
  done

  info "already installed: ${#already[@]}"
  if [ "${#unknown[@]}" -gt 0 ]; then
    warn "not found in your configured repositories: ${unknown[*]}"
    warn "skipping them. if one is in the AUR, install it with paru/yay and run this again."
    warn "the shell still starts without them, whatever needs them just won't show up."
  fi
  if [ "${#want[@]}" = 0 ]; then
    good "nothing to install"
  else
    info "to install (${#want[@]}): ${want[*]}"
    if ask "install these with pacman?"; then
      run sudo pacman -S --needed "${want[@]}" || die "pacman failed; fix the above and re-run"
    else
      warn "skipped. ./install.sh --list-packages explains what each one is for."
    fi
  fi
fi

if [ "$DO_BUILD" = 1 ]; then
  say "private Quickshell build"
  qs_bin="$("$ROOT/scripts/noctiluca-shell" --print-qs 2>/dev/null || true)"
  qs_prefix="$(dirname "$(dirname "$qs_bin")" 2>/dev/null || true)"
  if "$ROOT/scripts/noctiluca-shell" --check >/dev/null 2>&1 \
     && grep -qx screencopy "$qs_prefix/.noctiluca-features" 2>/dev/null \
     && grep -qx polkit "$qs_prefix/.noctiluca-features" 2>/dev/null \
     && grep -qx greetd "$qs_prefix/.noctiluca-features" 2>/dev/null; then
    good "a usable Quickshell is already in place ($qs_bin)"
  else
    if [ -n "$qs_bin" ] && [ ! -f "$qs_prefix/.noctiluca-features" ]; then
      info "your Quickshell build predates NOCTILUCA v2: it has no screencopy, which the overview needs"
    elif [ -n "$qs_bin" ] && ! grep -qx polkit "$qs_prefix/.noctiluca-features" 2>/dev/null; then
      info "your Quickshell build has no polkit agent, which the password prompt needs"
    elif [ -n "$qs_bin" ] && ! grep -qx greetd "$qs_prefix/.noctiluca-features" 2>/dev/null; then
      info "your Quickshell build has no greetd support, which the login screen needs"
    fi
    info "building Quickshell v0.3.2 into ~/.local/opt (the system package is left alone)"
    if [ "$DRY" = 1 ]; then
      run "$ROOT/scripts/build-quickshell.sh" --dry-run
    elif ask "build it now? (a few minutes)"; then
      bash "$ROOT/scripts/build-quickshell.sh" || die "the Quickshell build failed; see the output above"
    else
      warn "skipped. The shell will not start until it is built: scripts/build-quickshell.sh"
    fi
  fi
fi

if [ "$DO_LINKS" = 1 ]; then
  say "linking configuration into $CONFIG"
  run mkdir -p "$BIN" "$CONFIG/quickshell" "$CONFIG/kitty" "$CONFIG/noctiluca" "$STATE"

  while IFS='|' read -r target source; do
    [ -n "$target" ] || continue
    [ -e "$source" ] || { warn "missing in the repo, skipped: $source"; continue; }

    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]; then
      skipd "$target (already ours)"
      # record it anyway or --uninstall forgets links from older runs
      [ "$DRY" = 1 ] || { touch "$MANIFEST"; grep -qxF "$target" "$MANIFEST" || printf '%s\n' "$target" >> "$MANIFEST"; }
      continue
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
      what="file"; [ -d "$target" ] && what="directory"; [ -L "$target" ] && what="symlink"
      if ! ask "$target exists ($what). Move it to $BACKUP and replace it?"; then
        skipd "$target (left as it is)"
        continue
      fi
      chng "backup" "$target -> $BACKUP/"
      run mkdir -p "$BACKUP"
      run mv "$target" "$BACKUP/"
    fi

    chng "link" "$target -> $source"
    run mkdir -p "$(dirname "$target")"
    run ln -sfn "$source" "$target"
    [ "$DRY" = 1 ] || { touch "$MANIFEST"; grep -qxF "$target" "$MANIFEST" || printf '%s\n' "$target" >> "$MANIFEST"; }
  done < <(links)

  # so the bus sees the notifications service without a relogin
  if [ "$DRY" = 0 ] && command -v busctl >/dev/null 2>&1; then
    busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null 2>&1 || true
  fi

  if [ -f "$CONFIG/hypr/local.lua" ] || [ -f "$ROOT/config/hypr/local.lua" ]; then
    skipd "config/hypr/local.lua (already there; your settings are kept)"
  else
    chng "copy" "config/hypr/local.lua (from local.example.lua; edit your keyboard layout there)"
    run cp "$ROOT/config/hypr/local.example.lua" "$ROOT/config/hypr/local.lua"
  fi

  # sourced, not linked, so .zshrc stays yours
  # shellcheck disable=SC2016  # the literal line is what goes into .zshrc; zsh expands it
  zline='source "${XDG_CONFIG_HOME:-$HOME/.config}/noctiluca/prompt.zsh"'
  if [ -f "$HOME/.zshrc" ] && grep -qF 'noctiluca/prompt.zsh' "$HOME/.zshrc"; then
    skipd "$HOME/.zshrc already sources the prompt"
  elif ask "add the NOCTILUCA prompt to $HOME/.zshrc?"; then
    chng "append" "$HOME/.zshrc"
    if [ "$DRY" = 0 ]; then printf '\n# NOCTILUCA\n%s\n' "$zline" >> "$HOME/.zshrc"; fi
  fi

  # hypridle and the shell call the scripts by name
  case ":${PATH}:" in
    *":$BIN:"*) good "$BIN is on your PATH" ;;
    *) warn "$BIN is NOT on your PATH. Add it to your .zshrc (config/hypr/modules/env.lua adds it for the session)." ;;
  esac
fi

if [ "$DO_THEME" = 1 ]; then
  say "palette and themed files"
  export PATH="$BIN:$PATH"

  if [ -f "$STATE/palette.json" ]; then
    skipd "palette.json exists (change it with: noctiluca-wallpaper --set <image>)"
  else
    wall="$("$ROOT/scripts/noctiluca-wallpaper" --current 2>/dev/null || true)"
    if [ -n "$wall" ]; then
      chng "palette" "from your wallpaper"
      run python3 "$ROOT/scripts/noctiluca-palette" --image "$wall"
    else
      chng "palette" "from the reference hue (set a wallpaper later: noctiluca-wallpaper --random)"
      run python3 "$ROOT/scripts/noctiluca-palette" --reference
    fi
  fi

  chng "theme" "rendering kitty / GTK / Qt / Hyprland colours"
  run python3 "$ROOT/scripts/noctiluca-theme" --setup --no-reload
fi

echo
if [ "$DRY" = 1 ]; then
  bold "dry run finished, nothing was changed."
  exit 0
fi
bold "done."
echo
info "Next:"
info "  1. put some images in ~/Pictures/wallpapers, then:  noctiluca-wallpaper --random"
info "  2. edit your keyboard layout in config/hypr/local.lua"
info "  3. log in on a TTY and run:  Hyprland        (or use config/zsh/zprofile.example)"
info "  4. Super+Space launcher · Super+A control centre · Super+W wallpaper · Super+Escape power"
echo
info "Check everything first with: tests/lint.sh"
