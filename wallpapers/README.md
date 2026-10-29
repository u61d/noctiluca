# Wallpapers

None included, use your own. Drop them in any of these:

```
~/Pictures/wallpapers
~/Pictures/Wallpapers
~/.local/share/noctiluca/wallpapers
$NOCTILUCA_WALLPAPERS      (colon separated)
```

then `Super+W` or `noctiluca-wallpaper --random`.

The accent comes from the most common colourful hue in the picture. Darker pictures with one
clear colour (sky, water, a wall) work best. If a picture has two strong colours it might pick
the one you didn't want; set a fixed accent in settings or try `noctiluca-palette --hue N`.
Black and white pictures get a silver accent.

To see what a picture would give you without setting it:

```bash
noctiluca-palette --image photo.jpg --hue-only
```

or just arrow onto it in the picker, Escape puts everything back.
