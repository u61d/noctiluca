# Known limitations

## Not tried much yet

Everything passes the checks in `tests/lint.sh`, but these have only had a little real use (or
none):

- Wi-Fi and Bluetooth panels with a range of hardware
- the polkit prompt
- the live overview on NVIDIA. If windows only show icons, turn live previews off in
  Settings → Panels
- the greetd login screen on other machines
- battery stuff (I don't have a laptop to test on)
- multiple monitors and fractional scaling

## Good to know

- The first time you try the lockscreen, keep a second TTY logged in.
- While a panel is open it has the keyboard. Escape or clicking outside closes it.
- Panels open on the focused monitor.
- Only one notification daemon and one polkit agent can run. If you have mako, dunst,
  hyprpolkitagent or similar starting from somewhere, remove them.
- The keyboard layout set in settings overrides `kb_layout` in `local.lua`. Leave it empty to use
  `local.lua`.
- Lyrics come from LRCLIB, which doesn't have everything.
- The visualiser and the plankton need `cava`.
- Calendar times in a named timezone are read as local time.
- The bar shows up in screen shares. `config/hypr/modules/rules.lua` has the line to hide it.
- Video wallpapers aren't supported, they're skipped.

## Missing

- brightness for external monitors (DDC). Laptop backlights work
- a file browser in the wallpaper picker, it only shows the wallpaper folders
