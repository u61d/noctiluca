#!/usr/bin/env python3
"""checks design/tokens.json: bezier points in [-1, 2] and spring values > 0.5 (hyprland 0.56.2),
speed > 0, qml bezier x values in [0, 1], and wcag contrast.

    python3 tests/verify_tokens.py [path/to/tokens.json] [--json]
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
args = [a for a in sys.argv[1:] if not a.startswith("--")]
TOKENS = Path(args[0]) if args else ROOT / "design" / "tokens.json"
EMIT_JSON = "--json" in sys.argv

failures: list[str] = []
lines: list[str] = []


def check(ok: bool, label: str, detail: str = "") -> None:
    mark = "PASS" if ok else "FAIL"
    lines.append(f"  [{mark}] {label}" + (f"  ({detail})" if detail else ""))
    if not ok:
        failures.append(label)


# OKLCH -> sRGB with chroma gamut mapping, written separately from noctiluca_color.py on
# purpose
def oklch_to_linear(L: float, C: float, h_deg: float):
    h = math.radians(h_deg)
    a, b = C * math.cos(h), C * math.sin(h)
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    return (
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )


def in_gamut(rgb, eps=1e-4):
    return all(-eps <= c <= 1 + eps for c in rgb)


def gamut_map(L: float, C: float, h: float):
    """Reduce chroma (keeping L and h) until the colour fits in sRGB."""
    rgb = oklch_to_linear(L, C, h)
    if in_gamut(rgb):
        return rgb, C
    lo, hi = 0.0, C
    for _ in range(32):
        mid = (lo + hi) / 2
        if in_gamut(oklch_to_linear(L, mid, h)):
            lo = mid
        else:
            hi = mid
    return oklch_to_linear(L, lo, h), lo


def encode(c: float) -> int:
    c = min(1.0, max(0.0, c))
    v = 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055
    return round(v * 255)


def to_hex(rgb) -> str:
    return "#{:02x}{:02x}{:02x}".format(*(encode(c) for c in rgb))


def luminance(rgb) -> float:
    r, g, b = (min(1.0, max(0.0, c)) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(rgb_a, rgb_b) -> float:
    la, lb = luminance(rgb_a), luminance(rgb_b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


t = json.loads(TOKENS.read_text())

lines.append("spacing")
sp = t["spacing"]
vals = list(sp.values())
check(vals == sorted(vals), "spacing is strictly increasing")
check(all(v % 4 == 0 for k, v in sp.items() if k != "s1"), "every step except s1 is a multiple of 4")

lines.append("radius")
r = t["radius"]
inset = t["spacing"]["s3"]
check(r["panel"] - inset == r["field"],
      f"nesting rule: panel - s3({inset}) == field",
      f'{r["panel"]} - {inset} = {r["panel"] - inset}')
check(r["field"] - inset == r["chip"],
      f"nesting rule: field - s3({inset}) == chip",
      f'{r["field"]} - {inset} = {r["field"] - inset}')

lines.append("shell contract")
import re as _re
sh = t["shell"]
check(bool(_re.fullmatch(r"[a-z][a-z0-9]*", sh["appid"])), "appid is a simple lowercase word")
for key in ("shortcuts", "layers"):
    items = sh[key]
    check(len(items) == len(set(items)) and len(items) > 0, f"shell.{key}: non-empty and unique")
    check(all(_re.fullmatch(r"[a-z][a-z0-9-]*", i) for i in items), f"shell.{key}: names are lowercase-dash")

lines.append("motion")
m = t["motion"]
for name, c in m["curves"].items():
    x1, y1, x2, y2 = c["points"]
    check(all(-1 <= p <= 2 for p in c["points"]), f"curve '{name}' within Hyprland range [-1,2]")
    check(0 <= x1 <= 1 and 0 <= x2 <= 1, f"curve '{name}' x values within QML range [0,1]")

for name, d in m["duration_ms"].items():
    ds = d / 100.0
    check(0 < ds <= 100, f"duration '{name}' -> hl speed {ds:g} ds is in (0,100]")

spring_report = []
for name, s in m["springs"].items():
    ok = all(s[k] > 0.5 for k in ("mass", "stiffness", "damping"))
    check(ok, f"spring '{name}' mass/stiffness/damping all > 0.5")
    wn = math.sqrt(s["stiffness"] / s["mass"])
    zeta = s["damping"] / (2 * math.sqrt(s["stiffness"] * s["mass"]))
    # ~2% settling time: 4/(zeta*wn)
    settle_ms = 4.0 / (zeta * wn) * 1000
    overshoot = math.exp(-math.pi * zeta / math.sqrt(1 - zeta ** 2)) * 100 if zeta < 1 else 0.0
    spring_report.append((name, zeta, settle_ms, overshoot))
    check(0.6 <= zeta <= 1.0, f"spring '{name}' is calm (0.6 <= zeta <= 1.0)", f"zeta={zeta:.2f}")

lines.append("palette: reference")
p = t["palette"]
H = p["reference_hue"]
nl = p["neutral_lightness"]
chroma_n = p["neutral_chroma"]


def mk(L, C, h):
    rgb, used = gamut_map(L, C, h)
    return rgb, used


ref = {}
for k, L in nl.items():
    ref[k] = mk(L, chroma_n, H)
for k, v in p["accent"].items():
    ref[k] = mk(v["L"], v["C"], H)
ref["signal"] = mk(p["signal"]["L"], p["signal"]["C"], p["signal"]["hue"])

for k, (rgb, used) in ref.items():
    pass

g = p["contrast_guarantees"]
surfaces = ["void", "ink", "slate", "dusk"]


def sweep_min(fg_key, bg_key, fg_def, bg_def):
    """Minimum contrast over all hues 0..359 (5 degree steps)."""
    worst = 1e9
    worst_h = 0
    for h in range(0, 360, 5):
        fg = gamut_map(*fg_def, h)[0]
        bg = gamut_map(*bg_def, h)[0]
        c = contrast(fg, bg)
        if c < worst:
            worst, worst_h = c, h
    return worst, worst_h


def defn(key):
    if key in nl:
        return (nl[key], chroma_n)
    return (p["accent"][key]["L"], p["accent"][key]["C"])


lines.append("palette: contrast guaranteed over ALL hues (0-359, 5 degree steps)")
rules = [
    ("text", g["text_on_surfaces_min"]),
    ("dim", g["dim_on_surfaces_min"]),
    ("mute", g["mute_on_surfaces_min"]),
    ("glow", g["glow_on_surfaces_min"]),
]
sweep_rows = []
for fg, need in rules:
    for bg in surfaces:
        worst, wh = sweep_min(fg, bg, defn(fg), defn(bg))
        sweep_rows.append((fg, bg, worst, wh, need))
        check(worst >= need, f"{fg} on {bg} >= {need}", f"worst {worst:.2f} at hue {wh}")

worst, wh = sweep_min("line", "ink", defn("line"), defn("ink"))
check(worst >= g["line_vs_ink_min"], f"line vs ink >= {g['line_vs_ink_min']}", f"worst {worst:.2f} at hue {wh}")

worst = min(contrast(gamut_map(*defn("void"), h)[0], gamut_map(*defn("glow"), h)[0]) for h in range(0, 360, 5))
check(worst >= 7.0, "void on glow fill >= 7.0", f"worst {worst:.2f}")

lines.append("palette: ANSI terminal colours (fixed hues)")
an = p["ansi"]
ansi_surfaces = ["void", "ink", "slate"]
for hue_name, hue_deg in an["hues"].items():
    for tag, Lk, need in (("normal", "normal_L", g["ansi_normal_on_surfaces_min"]),
                          ("bright", "bright_L", g["ansi_bright_on_surfaces_min"])):
        fg = gamut_map(an[Lk], an["chroma"], hue_deg)[0]
        worst = min(contrast(fg, gamut_map(*defn(bg), H)[0]) for bg in ansi_surfaces)
        check(worst >= need, f"ansi {tag} {hue_name} on void/ink/slate >= {need}", f"worst {worst:.2f}")

clipped = []
for h in range(0, 360, 5):
    _, used = gamut_map(p["accent"]["glow"]["L"], p["accent"]["glow"]["C"], h)
    if used < p["accent"]["glow"]["C"] - 1e-3:
        clipped.append((h, used))
min_used = min(gamut_map(p["accent"]["glow"]["L"], p["accent"]["glow"]["C"], h)[1] for h in range(0, 360, 5))
check(min_used >= p["glow_chroma_floor"],
      f"glow chroma never drops below floor {p['glow_chroma_floor']} at any hue",
      f"min {min_used:.3f}, target {p['accent']['glow']['C']}, {len(clipped)}/72 hues clipped")

print(f"tokens: {TOKENS}")
print("\n".join(lines))
print()
print(f"reference palette (hue {H}, OKLCH -> sRGB):")
for k, (rgb, used) in ref.items():
    print(f"  {k:8s} {to_hex(rgb)}   (C used {used:.3f})")
print()
print("reference contrast (hue %d):" % H)
for fg in ("text", "dim", "mute", "glow"):
    row = []
    for bg in surfaces:
        row.append(f"{bg} {contrast(ref[fg][0], ref[bg][0]):5.1f}")
    print(f"  {fg:5s} on  " + "   ".join(row))
print()
print("springs:")
for name, zeta, settle, ov in spring_report:
    print(f"  {name:6s} zeta={zeta:.2f}  ~2% settle {settle:4.0f} ms  overshoot {ov:4.1f}%")
if clipped:
    print()
    print("hues where glow chroma is clipped (hue: chroma used):",
          ", ".join(f"{h}:{c:.3f}" for h, c in clipped))
print()
if EMIT_JSON:
    out = {k: to_hex(v[0]) for k, v in ref.items()}
    print(json.dumps(out, indent=2))
    print()

if failures:
    print(f"RESULT: {len(failures)} check(s) FAILED")
    for f in failures:
        print("  -", f)
    sys.exit(1)
print("RESULT: all checks passed")
