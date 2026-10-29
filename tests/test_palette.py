#!/usr/bin/env python3
"""noctiluca_color.py and noctiluca-palette. needs Pillow."""
import importlib.util
import json
import math
import random
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts" / "lib"))
import noctiluca_color as nc  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

TOKENS = nc.load_tokens(ROOT / "design" / "tokens.json")
SCRIPT = ROOT / "scripts" / "noctiluca-palette"
fails: list[str] = []


def check(ok: bool, label: str, detail: str = "") -> None:
    print(f"  [{'PASS' if ok else 'FAIL'}] {label}" + (f"  ({detail})" if detail else ""))
    if not ok:
        fails.append(label)


def hue_dist(a: float, b: float) -> float:
    d = abs(a - b) % 360
    return min(d, 360 - d)


def solid_noise(rgb, size=(320, 180), jitter=18, seed=1):
    rnd = random.Random(seed)
    im = Image.new("RGB", size)
    px = im.load()
    for y in range(size[1]):
        for x in range(size[0]):
            px[x, y] = tuple(max(0, min(255, c + rnd.randint(-jitter, jitter))) for c in rgb)
    return im


def lch_to_rgb8(L, C, h):
    rgb, _ = nc.gamut_map(L, C, h)
    return nc.linear_to_rgb8(rgb)


tmp = Path(tempfile.mkdtemp(prefix="noct-test-"))

print("colour math")
worst = 0.0
for L in (0.2, 0.5, 0.8):
    for h in range(0, 360, 30):
        rgb8 = lch_to_rgb8(L, 0.06, h)
        L2, C2, h2 = nc.rgb8_to_oklch(*rgb8)
        worst = max(worst, abs(L - L2))
check(worst < 0.01, "OKLCH -> sRGB8 -> OKLCH keeps lightness", f"worst dL {worst:.4f}")

print("cross-check with tests/verify_tokens.py")
out = subprocess.run([sys.executable, str(ROOT / "tests" / "verify_tokens.py"), "--json"],
                     capture_output=True, text=True)
check(out.returncode == 0, "verify_tokens.py passes", f"exit {out.returncode}")
ref_json = json.loads(out.stdout[out.stdout.index("{"):out.stdout.rindex("}") + 1])
mine = nc.render_roles(TOKENS, TOKENS["palette"]["reference_hue"])
mismatch = [k for k, v in ref_json.items() if mine.get(k) != v]
check(not mismatch, "library reproduces verify_tokens reference palette hex-for-hex",
      f"mismatch: {mismatch}" if mismatch else f"{len(ref_json)} roles identical")

print("guarantees for every accent hue (0-359, step 3)")
bad_hues = []
for h in range(0, 360, 3):
    v = nc.contrast_violations(TOKENS, nc.render_roles(TOKENS, h))
    if v:
        bad_hues.append((h, v[0]))
check(not bad_hues, "all contrast guarantees (incl. ANSI) hold for 120 hues",
      f"first failure {bad_hues[0]}" if bad_hues else "")

print("hue extraction")
cases = []
teal = lch_to_rgb8(0.55, 0.10, 195)
cases.append(("teal wallpaper", solid_noise(teal), 195, 12))
red = lch_to_rgb8(0.55, 0.14, 30)
cases.append(("red-orange wallpaper", solid_noise(red, seed=2), 30, 12))
violet = lch_to_rgb8(0.50, 0.12, 300)
cases.append(("violet wallpaper", solid_noise(violet, seed=3), 300, 12))

# grey with a small saturated patch (~6%)
grey = solid_noise((110, 110, 112), seed=4)
d = ImageDraw.Draw(grey)
d.rectangle([10, 10, 80, 50], fill=lch_to_rgb8(0.60, 0.15, 145))
cases.append(("grey + small green patch", grey, 145, 15))

# 65% green vs 35% magenta, green wins
two = Image.new("RGB", (320, 180), lch_to_rgb8(0.58, 0.12, 145))
ImageDraw.Draw(two).rectangle([208, 0, 320, 180], fill=lch_to_rgb8(0.58, 0.12, 335))
cases.append(("65% green / 35% magenta", two, 145, 15))

# same hue across the 0/360 seam
seam = Image.new("RGB", (320, 180), lch_to_rgb8(0.58, 0.12, 352))
ImageDraw.Draw(seam).rectangle([160, 0, 320, 180], fill=lch_to_rgb8(0.58, 0.12, 8))
cases.append(("hue seam at 0/360", seam, 0, 15))

for name, im, expect, tol in cases:
    p = tmp / (name.replace(" ", "_").replace("/", "-").replace("%", "") + ".png")
    im.save(p)
    hue, info = nc.extract_hue(p, TOKENS)
    check(hue_dist(hue, expect) <= tol, f"{name}: expected ~{expect}", f"got {hue}")

for name, im in [
    ("pure grey", Image.new("RGB", (200, 120), (128, 128, 128))),
    ("near-black photo", solid_noise((6, 8, 9), jitter=3, seed=5)),
    ("near-white", solid_noise((250, 250, 248), jitter=3, seed=6)),
    ("1x1 pixel", Image.new("RGB", (1, 1), (128, 128, 128))),
]:
    p = tmp / (name.replace(" ", "_") + ".png")
    im.save(p)
    hue, info = nc.extract_hue(p, TOKENS)
    check(hue == TOKENS["palette"]["reference_hue"] and "fallback" in info,
          f"{name}: falls back to reference hue", f"got {hue} {info.get('fallback', '')}")

import random as _r
_r.seed(11)
manga = Image.new("RGB", (480, 300), (246, 243, 236))
md = ImageDraw.Draw(manga)
for _ in range(6):
    x, y = _r.randint(0, 300), _r.randint(0, 180)
    md.rectangle((x, y, x + 170, y + 110), outline=(12, 12, 12), width=4)
    for _k in range(250):
        g = _r.randint(60, 200)
        md.point((x + _r.randint(0, 170), y + _r.randint(0, 110)), fill=(g, g, g))
md.rectangle((14, 14, 70, 34), fill=(200, 30, 30))          # a small red title
grey_sign = Image.new("RGB", (480, 300), (120, 120, 120))
ImageDraw.Draw(grey_sign).rectangle((200, 120, 250, 150), fill=(220, 30, 40))
for name, im, want in [("manga page with a red title", manga, True),
                       ("grey photo with one red sign", grey_sign, True),
                       ("a real colour picture", two, False)]:
    q = tmp / (name.replace(" ", "_") + ".jpg")
    im.save(q, quality=75)
    hue, info = nc.extract_hue(q, TOKENS)
    check(bool(info.get("mono")) == want, f"{name}: {'black and white' if want else 'has a hue'}", str(info.get("mean_chroma")))

mono_roles = nc.render_roles(TOKENS, TOKENS["palette"]["reference_hue"], mono=True)
_, gc, _ = nc.rgb8_to_oklch(*nc.hex_to_rgb8(mono_roles["glow"]))
check(gc < 0.02, "black and white: the accent is silver, not a colour", f"chroma {gc:.3f}")
check(not nc.contrast_violations(TOKENS, mono_roles), "black and white: every contrast guarantee still holds")
r = subprocess.run([sys.executable, str(ROOT / "scripts" / "noctiluca-palette"), "--image", str(tmp / "manga_page_with_a_red_title.jpg"),
                    "--out", "-"], capture_output=True, text=True)
doc = json.loads(r.stdout) if r.returncode == 0 else {}
check(doc.get("mono") is True and doc.get("roles", {}).get("glow") == mono_roles["glow"],
      "noctiluca-palette writes the black-and-white palette for it", r.stderr.strip()[:80])

pal = Image.new("P", (64, 64)); pal.putpalette([255, 0, 0] + [0] * 765)
cmyk = Image.new("CMYK", (64, 64), (0, 255, 255, 0))
rgba = Image.new("RGBA", (64, 64), (0, 120, 255, 255))
for name, im in [("palette-mode", pal), ("CMYK", cmyk), ("RGBA", rgba)]:
    p = tmp / f"mode_{name}.png" if name != "CMYK" else tmp / "mode_cmyk.tiff"
    im.save(p)
    try:
        hue, _ = nc.extract_hue(p, TOKENS)
        check(0 <= hue < 360, f"{name} image is readable", f"hue {hue}")
    except Exception as e:  # noqa: BLE001
        check(False, f"{name} image is readable", str(e))

p = tmp / "teal_wallpaper.png"
check(nc.extract_hue(p, TOKENS) == nc.extract_hue(p, TOKENS), "extraction is deterministic")

print("performance")
big = Image.effect_noise((4000, 3000), 40).convert("RGB")
tinted = Image.merge("RGB", (big.getchannel(0), big.getchannel(0).point(lambda v: v // 2), big.getchannel(0).point(lambda v: v // 3)))
bp = tmp / "big.jpg"
tinted.save(bp, quality=85)
t0 = time.perf_counter()
nc.extract_hue(bp, TOKENS)
dt = (time.perf_counter() - t0) * 1000
check(dt < 1500, "4000x3000 JPEG extracts in < 1.5 s", f"{dt:.0f} ms")

print("CLI")
r = subprocess.run([sys.executable, str(SCRIPT), "--image", str(tmp / "teal_wallpaper.png"), "--out", "-"],
                   capture_output=True, text=True)
doc = json.loads(r.stdout) if r.returncode == 0 else {}
check(r.returncode == 0 and doc.get("schema") == 1 and len(doc.get("roles", {})) == 28,
      "palette.json has schema 1 and 28 roles", f"{len(doc.get('roles', {}))} roles")
r = subprocess.run([sys.executable, str(SCRIPT), "--image", "/nonexistent.png"], capture_output=True, text=True)
check(r.returncode == 1 and "cannot read image" in r.stderr, "missing image -> exit 1 with message")
r = subprocess.run([sys.executable, str(SCRIPT), "--image", str(tmp / "teal_wallpaper.png"), "--hue-only"],
                   capture_output=True, text=True)
check(r.returncode == 0 and "hue" in json.loads(r.stdout), "--hue-only prints hue JSON")
sd = tmp / "state"
env = {"XDG_STATE_HOME": str(sd), "PATH": "/usr/bin:/bin"}
r1 = subprocess.run([sys.executable, str(SCRIPT), "--hue", "140"], capture_output=True, text=True, env=env)
r2 = subprocess.run([sys.executable, str(SCRIPT), "--hue", "140"], capture_output=True, text=True, env=env)
check("written" in r1.stdout and "unchanged" in r2.stdout, "idempotent: second run reports 'unchanged'")

print()
if fails:
    print(f"RESULT: {len(fails)} FAILED")
    for f in fails:
        print("  -", f)
    sys.exit(1)
print("RESULT: all palette tests passed")
