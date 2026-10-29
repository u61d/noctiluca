# Design notes

The idea is plankton in dark water: everything stays dark, and light only shows up where
something happens.

## The ink

The bar is one dark shape across the top with three "pools" in it (workspaces and title on the
left, music in the middle, status on the right). Panels hang down out of the same shape, so
opening one looks like the ink stretching instead of a window popping up.

It's all a single shader (`shell/shaders/waterline.frag`), a signed distance field. The pieces are
merged with a smooth union, which is where the rounded joins between the bar and a panel come
from. The shader doesn't use time, so it only redraws when something actually changes.

## Light

The accent is used as light, almost never as a fill: the thin rim along the edge, a glow near the
pointer, a ripple when you switch workspace, a ring where you click. With music playing the rim
picks up the bass (you can turn that off in Settings → Look).

## Motion

Anything that moves is on a spring (`shell/components/Spring.qml`). The main reason is that
springs keep their speed when the target changes, so if you close a panel halfway through
opening it, it just turns around.

Panels are laid out at their final size and slide out from behind the bar. Nothing inside gets
resized while it moves. A moving panel sags a little at the bottom, like a hanging drop, and
flattens out when it stops. Opening overshoots slightly, closing never does.

"Reduce motion" in settings replaces the slides with fades.

## Colour

One accent hue from the wallpaper, plus dark neutrals tinted with the same hue. Only the hue
changes between wallpapers, the lightness of every colour is fixed, so contrast stays the same
whatever you pick. `tests/verify_tokens.py` checks that at every hue (body text at least 12:1,
the accent at least 7:1).

The hue is the most common colourful, mid-bright hue in the picture. Black and white pictures
(manga pages, b&w photos) get an almost colourless silver accent instead of a hue from paper
tint. The music player does the same with album art.

There's one red, only for errors and destructive stuff, and muted ANSI colours for the terminal.

## Type and icons

IBM Plex Sans for text, Plex Mono for numbers and times. Icons are [Lucide](https://lucide.dev),
converted to paths so they're drawn like everything else. Apps keep their own icons.

## Spacing

4px grid. Big panels have 22px corners, things inside them 12px, small marks 4px.
