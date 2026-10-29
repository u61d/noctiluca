# How it fits together

## Shared numbers

`design/tokens.json` has the spacing, fonts, animation curves, colour rules and the names
Hyprland and the shell both need (shortcut and layer names). `scripts/gen-tokens` turns it into
`config/hypr/tokens.lua` and `shell/core/Tokens.qml`. Lint fails if those are out of date.

## Colours

```
wallpaper -> noctiluca-palette -> ~/.local/state/noctiluca/palette.json
                                        |
                       +----------------+----------------+
                 noctiluca-theme                  shell/core/Theme.qml
   kitty, gtk, qt, hyprland, fastfetch, zsh         (watches the file)
```

`noctiluca-wallpaper --set` builds the palette first and only records the wallpaper if that
worked, then rethemes. The picker previews a hue without writing anything (`Theme.previewHue`).

## Settings

`~/.config/noctiluca/settings.json` is loaded by `shell/core/Settings.qml` and everything binds
to it directly, which is why changes apply instantly. Hyprland options go out through
`hyprctl eval` and get saved to `~/.local/state/noctiluca/hypr.lua`, which
`config/hypr/modules/user.lua` loads on startup.

## The shell

Per screen:

```
Wallpaper   background layer   the image and the transition between images
Desktop     bottom layer       the big clock and the plankton
Exclusion   bottom layer       1px window that reserves space for the bar
Surface     top layer          the ink, pools and panels; only the ink takes clicks
```

Plus the lockscreen, the settings window, the screenshot overlay, the polkit prompt and the
global shortcuts, once each. The login screen has its own root in `greeter/shell.qml`.

`Surface.qml` has two panel sheets so one can close while another opens, plus one for
notifications. Panels are loaded by URL, so a panel that fails to load (the overview on a
Quickshell without screencopy) shows an error instead of breaking the bar.
`services/Panels.qml` keeps track of what's open.

Most services only poll while something is showing them. The exceptions are the cheap /proc
reads for the dashboard graphs (every 2s, so they open with some history) and the calendar
(every 15 minutes, only if you added one).

## Tests

`tests/lint.sh` runs everything. Roughly: token and contrast checks, the theme templates, the
Hyprland config against a mock built from Hyprland's source, the QML against Quickshell's API
and through a real Qt engine, shader output pixel by pixel, and the scripts and installer in a
fake home. None of that can check things that need a running Hyprland (focus, PAM, screencopy).
