#!/usr/bin/env python3
"""Regenerates shell/components/Icons.qml from lucide's icon-nodes.json.

    npm pack lucide-static@0.460.0 && tar xzf lucide-static-0.460.0.tgz
    scripts/dev/gen-icons.py package/icon-nodes.json shell/components/Icons.qml

MAP is the whole set: our name on the left, lucide's on the right.
"""
import json, re, sys
nodes = json.load(open(sys.argv[1]))
MAP = {
 "play": "play", "pause": "pause", "next": "skip-forward", "previous": "skip-back",
 "shuffle": "shuffle", "repeat": "repeat", "music": "music", "lyrics": "mic-vocal",
 "volume": "volume-2", "volumeLow": "volume-1", "volumeMute": "volume-x", "mic": "mic", "micOff": "mic-off",
 "headphones": "headphones", "speaker": "speaker", "mixer": "sliders-vertical",
 "wifi": "wifi", "wifiLow": "wifi-low", "wifiOff": "wifi-off", "wired": "ethernet-port",
 "bluetooth": "bluetooth", "bluetoothOn": "bluetooth-connected", "bluetoothOff": "bluetooth-off",
 "airplane": "plane", "vpn": "shield",
 "power": "power", "lock": "lock", "logout": "log-out", "hibernate": "hard-drive-download",
 "suspend": "moon", "reboot": "rotate-cw", "user": "user-round",
 "sun": "sun", "moon": "moon", "cloud": "cloud", "sunCloud": "cloud-sun", "moonCloud": "cloud-moon",
 "fog": "cloud-fog", "rain": "cloud-rain", "snow": "cloud-snow", "storm": "cloud-lightning",
 "drizzle": "cloud-drizzle", "wind": "wind", "droplet": "droplet",
 "bell": "bell", "bellOff": "bell-off", "bellDot": "bell-dot", "settings": "settings",
 "brightness": "sun-medium", "brightnessLow": "sun-dim", "nightLight": "moon-star", "caffeine": "coffee",
 "keyboard": "keyboard", "languages": "languages",
 "battery": "battery", "batteryLow": "battery-low", "batteryMedium": "battery-medium",
 "batteryFull": "battery-full", "batteryCharging": "battery-charging", "batteryWarning": "battery-warning",
 "plug": "plug-zap", "powerSaver": "leaf", "balanced": "gauge", "performance": "zap",
 "cpu": "cpu", "memory": "memory-stick", "disk": "hard-drive", "gpu": "microchip", "network": "network",
 "download": "arrow-down", "upload": "arrow-up", "monitor": "monitor",
 "screenshot": "camera", "record": "video", "stop": "square", "region": "square-dashed-mouse-pointer",
 "window": "app-window", "screen": "monitor", "crop": "crop", "scanText": "scan-text", "cursor": "mouse-pointer-2",
 "search": "search", "app": "layout-grid", "file": "file", "folder": "folder", "image": "image",
 "calculator": "calculator", "colorPicker": "pipette", "palette": "palette", "emoji": "smile",
 "clipboard": "clipboard", "terminal": "square-terminal", "windows": "app-window-mac", "ruler": "ruler",
 "overview": "layout-dashboard", "wallpaper": "image",
 "close": "x", "check": "check", "plus": "plus", "minus": "minus", "trash": "trash-2", "send": "send-horizontal",
 "reply": "reply", "chevronDown": "chevron-down", "chevronUp": "chevron-up", "chevronLeft": "chevron-left",
 "chevronRight": "chevron-right", "calendar": "calendar", "clock": "clock", "pin": "map-pin",
 "refresh": "refresh-cw", "external": "external-link", "eye": "eye", "eyeOff": "eye-off", "dots": "ellipsis",
 "info": "info", "alert": "triangle-alert", "link": "link", "copy": "copy",
}

def f(v): 
    v = float(v); return ("%g" % round(v, 3))

NUM = re.compile(r"[a-zA-Z]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")


def absolute_start(d):
    """A path's first "m x y" is absolute even when lowercase, and the pairs after it are
    relative lines. Spell that out ("M x y l ...") so the path still means the same thing once
    it's joined onto another one."""
    tok = NUM.findall(d)
    if not tok or tok[0] != "m":
        return d
    out = ["M", tok[1], tok[2]]
    rest = tok[3:]
    if rest and not rest[0].isalpha():
        out.append("l")
    return " ".join(out + rest)


def to_path(tag, a):
    # join the elements into one path; a leading relative "m" would otherwise start wherever
    # the previous element ended
    if tag == "path":
        return absolute_start(a["d"])
    if tag == "line": return f"M{f(a['x1'])} {f(a['y1'])}L{f(a['x2'])} {f(a['y2'])}"
    if tag in ("polyline", "polygon"):
        pts = a["points"].replace(",", " ").split()
        pairs = [(pts[i], pts[i+1]) for i in range(0, len(pts), 2)]
        d = "M" + "L".join(f"{f(x)} {f(y)}" for x, y in pairs)
        return d + ("Z" if tag == "polygon" else "")
    if tag in ("circle", "ellipse"):
        cx, cy = float(a["cx"]), float(a["cy"])
        rx = float(a.get("r", a.get("rx"))); ry = float(a.get("r", a.get("ry")))
        return (f"M{f(cx-rx)} {f(cy)}A{f(rx)} {f(ry)} 0 1 0 {f(cx+rx)} {f(cy)}"
                f"A{f(rx)} {f(ry)} 0 1 0 {f(cx-rx)} {f(cy)}Z")
    if tag == "rect":
        x, y, w, h = (float(a[k]) for k in ("x", "y", "width", "height"))
        rx = float(a.get("rx", a.get("ry", 0))); ry = float(a.get("ry", rx))
        rx = min(rx, w/2); ry = min(ry, h/2)
        if rx == 0:
            return f"M{f(x)} {f(y)}H{f(x+w)}V{f(y+h)}H{f(x)}Z"
        return (f"M{f(x+rx)} {f(y)}H{f(x+w-rx)}A{f(rx)} {f(ry)} 0 0 1 {f(x+w)} {f(y+ry)}"
                f"V{f(y+h-ry)}A{f(rx)} {f(ry)} 0 0 1 {f(x+w-rx)} {f(y+h)}"
                f"H{f(x+rx)}A{f(rx)} {f(ry)} 0 0 1 {f(x)} {f(y+h-ry)}"
                f"V{f(y+ry)}A{f(rx)} {f(ry)} 0 0 1 {f(x+rx)} {f(y)}Z")
    raise SystemExit(f"unhandled element {tag}")

missing = [v for v in MAP.values() if v not in nodes]
if missing: raise SystemExit(f"not in lucide: {missing}")
out = ['pragma Singleton', 'import Quickshell', '',
 '// Every icon in the shell, as SVG path data on a 24 px grid, drawn by Icon.qml as strokes.',
 '// They are Lucide (https://lucide.dev, ISC licence; see docs/THIRD-PARTY.md), converted by',
 '// scripts/dev/gen-icons.py: circles, rects and lines become plain paths so one ShapePath',
 '// can draw any of them. Don\'t edit by hand; change the table in the script and run it again.',
 'Singleton {', '    readonly property int grid: 24', '']
for name, luc in MAP.items():
    d = " ".join(to_path(tag, a) for tag, a in nodes[luc])
    out.append(f'    readonly property string {name}: "{d}"   // {luc}')
out.append('}')
open(sys.argv[2], "w").write("\n".join(out) + "\n")
print(len(MAP), "icons")
