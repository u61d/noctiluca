# Performance

I aimed for a steady 180 Hz at 1080p on a GTX 1080.

Why it stays fairly cheap:

- the ink shader doesn't use time, so a still desktop isn't redrawn
- no blur behind the bar, the ink draws its own shadow
- panels load when opened and unload when closed, along with anything they poll
- panel content is never resized while it animates
- wallpapers are decoded at screen size and the old one is dropped after the transition
- the overview only shows the big workspace as live video, the small cards are just drawn
- the plankton has its own small window, so redrawing it doesn't touch the rest

## Memory

`noctiluca-ctl mem` shows what the shell uses. Expect around 150 to 300 MB on one monitor, most of
that is Qt itself. It's lowest right after login, so check after opening a few panels.

## On slower machines

In settings, roughly in order of how much they save: overview live previews off (Panels),
plankton off (Desktop), wallpaper transition off (Desktop), visualiser off (Panels), then blur,
shadows and glow (Windows). Reduce motion also helps a bit.

## Dropped frames

1. `hyprctl layers`: is another bar still running?
2. `pgrep -ax 'cava|wl-paste'`: more than one of each means the shell is running twice.
   `noctiluca-shell kill` and start it once.
3. Close all panels. If it still stutters, it's probably window effects, not the shell.
