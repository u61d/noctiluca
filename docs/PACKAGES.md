# Packages

`./install.sh --list-packages` prints everything with a reason. `./install.sh --packages` installs
them (after asking). Names your repos don't have are skipped and reported.

## Quickshell

The installer builds Quickshell 0.3.2 into `~/.local/opt/quickshell-0.3.2` and doesn't touch an
installed one. A lot of setups use an AUR Quickshell that conflicts with the official package,
and installing one makes pacman remove the other for everyone on the machine. A copy in your home
avoids that.

Quickshell uses private Qt APIs, so after a Qt update it needs a rebuild. `noctiluca-shell` will
tell you:

```bash
scripts/build-quickshell.sh
```

## What it installs

- build: `base-devel git cmake ninja pkgconf qt6-base qt6-declarative qt6-shadertools spirv-tools
  cli11 libdrm wayland wayland-protocols pipewire pam jemalloc mesa vulkan-headers polkit`
- compositor: `hyprland hypridle xdg-desktop-portal-hyprland xdg-desktop-portal-gtk`
- runtime: `qt6-wayland qt6-svg networkmanager bluez bluez-utils power-profiles-daemon
  pipewire-pulse wireplumber cliphist wl-clipboard grim brightnessctl libnotify cava curl jq`
- look: `ttf-ibm-plex adw-gtk-theme breeze-icons qt6ct kvantum`
- colours: `python python-pillow`
- terminal: `kitty zsh fastfetch zsh-autosuggestions zsh-syntax-highlighting eza
  ttf-nerd-fonts-symbols-mono`
- optional, for `tests/lint.sh`: `shellcheck glslang`, and PySide6 (`pip install --user pyside6`)

## Things it replaces

The shell does these itself, so they shouldn't be running in this session: waybar, eww, rofi,
mako, dunst, swaync, wlogout, hyprlock, hyprpaper, swww, hyprpolkitagent, polkit-gnome. The
installer warns about them but doesn't uninstall anything.

## NVIDIA

Nothing extra gets installed. `config/hypr/modules/env.lua` detects the proprietary driver and
sets the environment. `libva-nvidia-driver` is worth having for video decoding in browsers.
