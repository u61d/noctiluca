"""Colour engine for noctiluca-palette, noctiluca-theme and the tests: oklch <-> srgb,
chroma-only gamut mapping, wcag contrast, the roles for a hue, and the hue of a wallpaper.
Everything comes from design/tokens.json. Pillow is only needed for extract_hue.
"""
from __future__ import annotations

import json
import math
import os
from pathlib import Path

GENERATOR = "noctiluca-palette 1.0"


def find_tokens(start: Path | None = None) -> Path:
    """NOCTILUCA_TOKENS, else <repo>/design/tokens.json relative to this file."""
    env = os.environ.get("NOCTILUCA_TOKENS")
    if env:
        return Path(env)
    here = (start or Path(__file__)).resolve()
    for parent in here.parents:
        cand = parent / "design" / "tokens.json"
        if cand.is_file():
            return cand
    raise FileNotFoundError("design/tokens.json not found (set NOCTILUCA_TOKENS)")


def load_tokens(path: Path | None = None) -> dict:
    return json.loads(Path(path or find_tokens()).read_text())



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


def _in_gamut(rgb, eps=1e-4) -> bool:
    return all(-eps <= c <= 1 + eps for c in rgb)


def gamut_map(L: float, C: float, h: float):
    """lower chroma until it fits srgb -> (linear_rgb, chroma_used)"""
    rgb = oklch_to_linear(L, C, h)
    if _in_gamut(rgb):
        return rgb, C
    lo, hi = 0.0, C
    for _ in range(32):
        mid = (lo + hi) / 2
        if _in_gamut(oklch_to_linear(L, mid, h)):
            lo = mid
        else:
            hi = mid
    return oklch_to_linear(L, lo, h), lo


def _encode(c: float) -> int:
    c = min(1.0, max(0.0, c))
    v = 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055
    return round(v * 255)


def linear_to_rgb8(rgb) -> tuple[int, int, int]:
    return tuple(_encode(c) for c in rgb)  # type: ignore[return-value]


def rgb8_to_hex(rgb8) -> str:
    return "#{:02x}{:02x}{:02x}".format(*rgb8)


def hex_to_rgb8(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def _decode(v8: int) -> float:
    c = v8 / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb8_to_oklch(r8: int, g8: int, b8: int):
    r, g, b = _decode(r8), _decode(g8), _decode(b8)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l_, m_, s_ = l ** (1 / 3), m ** (1 / 3), s ** (1 / 3)
    L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    return L, math.hypot(a, bb), math.degrees(math.atan2(bb, a)) % 360.0


def luminance_linear(rgb) -> float:
    r, g, b = (min(1.0, max(0.0, c)) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_hex(a: str, b: str) -> float:
    la = luminance_linear([_decode(v) for v in hex_to_rgb8(a)])
    lb = luminance_linear([_decode(v) for v in hex_to_rgb8(b)])
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


ANSI_ORDER = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]


# black and white wallpapers get a silver accent: same lightness (so contrast still holds),
# almost no chroma
MONO_ACCENT_CHROMA = 0.012


def role_definitions(tokens: dict, hue: float, mono: bool = False) -> dict[str, tuple[float, float, float]]:
    """role -> (L, C, h) for a given accent hue. Order matters (stable output)."""
    p = tokens["palette"]
    out: dict[str, tuple[float, float, float]] = {}
    for name, L in p["neutral_lightness"].items():
        out[name] = (L, 0.0 if mono else p["neutral_chroma"], hue)
    for name, v in p["accent"].items():
        out[name] = (v["L"], min(v["C"], MONO_ACCENT_CHROMA) if mono else v["C"], hue)
    sig = p["signal"]
    out["signal"] = (sig["L"], sig["C"], sig["hue"])
    a = p["ansi"]
    for name, h in a["hues"].items():
        out[f"ansi_{name}"] = (a["normal_L"], a["chroma"], h)
        out[f"ansi_bright_{name}"] = (a["bright_L"], a["chroma"], h)
    return out


def render_roles(tokens: dict, hue: float, mono: bool = False) -> dict[str, str]:
    """role -> '#rrggbb'. ANSI black/white slots reuse neutrals."""
    roles: dict[str, str] = {}
    for name, (L, C, h) in role_definitions(tokens, hue, mono).items():
        rgb, _ = gamut_map(L, C, h)
        roles[name] = rgb8_to_hex(linear_to_rgb8(rgb))
    roles["ansi_black"] = roles["line"]
    roles["ansi_bright_black"] = roles["mute"]
    roles["ansi_white"] = roles["dim"]
    roles["ansi_bright_white"] = roles["text"]
    return roles


def contrast_violations(tokens: dict, roles: dict[str, str]) -> list[str]:
    """contrast problems in a rendered palette, empty if fine"""
    g = tokens["palette"]["contrast_guarantees"]
    surfaces = ["void", "ink", "slate", "dusk"]
    bad: list[str] = []

    def need(fg: str, minimum: float, bgs=surfaces):
        for bg in bgs:
            c = contrast_hex(roles[fg], roles[bg])
            if c < minimum:
                bad.append(f"{fg} on {bg}: {c:.2f} < {minimum}")

    need("text", g["text_on_surfaces_min"])
    need("dim", g["dim_on_surfaces_min"])
    need("mute", g["mute_on_surfaces_min"])
    need("glow", g["glow_on_surfaces_min"])
    for n in ("red", "green", "yellow", "blue", "magenta", "cyan"):
        need(f"ansi_{n}", g["ansi_normal_on_surfaces_min"], ["void", "ink", "slate"])
        need(f"ansi_bright_{n}", g["ansi_bright_on_surfaces_min"], ["void", "ink", "slate"])
    c = contrast_hex(roles["line"], roles["ink"])
    if c < g["line_vs_ink_min"]:
        bad.append(f"line vs ink: {c:.2f} < {g['line_vs_ink_min']}")
    return bad


BINS = 72  # 5 degrees per bin
_SMOOTH = (1, 2, 3, 2, 1)  # circular kernel


def extract_hue(path: str | Path, tokens: dict, size: int = 96, min_usable: float = 0.02):
    """-> (hue, info). info["mono"] means there's no real colour in it (manga, b&w photos),
    so don't take a hue from paper tint or jpeg noise. too dark/bright falls back to the
    reference hue"""
    from PIL import Image  # imported lazily: only this function needs Pillow

    ref = float(tokens["palette"]["reference_hue"])
    with Image.open(path) as im:
        try:
            im.draft("RGB", (size * 2, size * 2))  # JPEG: decode at reduced size
        except Exception:
            pass
        im = im.convert("RGB")
        im.thumbnail((size, size), Image.Resampling.BOX)
        pixels = list(im.getdata())

    total = len(pixels)
    seen = 0
    chroma_sum = 0.0
    strong = 0
    for r8, g8, b8 in pixels:
        L, C, _ = rgb8_to_oklch(r8, g8, b8)
        if L < 0.15:
            continue
        seen += 1
        chroma_sum += C
        if C >= 0.06 and L <= 0.95:
            strong += 1
    mean_chroma = chroma_sum / seen if seen else 0.0
    strong_frac = strong / total if total else 0.0

    weights = [0.0] * BINS
    vx = [0.0] * BINS
    vy = [0.0] * BINS
    usable = 0
    for r8, g8, b8 in pixels:
        L, C, h = rgb8_to_oklch(r8, g8, b8)
        if L < 0.15 or L > 0.92 or C < 0.03:
            continue
        w = C * max(0.0, 1.0 - abs(L - 0.60) / 0.45)  # chromatic, mid-lightness pixels win
        if w <= 0.0:
            continue
        usable += 1
        i = int(h // 5) % BINS
        weights[i] += w
        rad = math.radians(h)
        vx[i] += w * math.cos(rad)
        vy[i] += w * math.sin(rad)

    frac = usable / total if total else 0.0
    info = {"pixels": total, "usable_fraction": round(frac, 4),
            "mean_chroma": round(mean_chroma, 4), "colourful_fraction": round(strong_frac, 4)}
    # manga test: under 2% properly coloured is a title or stamp on a grey page. a grey photo
    # with a real patch of colour (neon sign, red coat) has more and keeps its hue
    if seen >= total * 0.25 and (mean_chroma < 0.008 or strong_frac < 0.02):
        info["mono"] = True
        info["fallback"] = "monochrome"
        return ref, info
    if frac < min_usable or sum(weights) <= 1e-9:
        info["fallback"] = "monochrome-or-extreme-lightness"
        return ref, info

    k = len(_SMOOTH) // 2
    smooth = [
        sum(_SMOOTH[j] * weights[(i + j - k) % BINS] for j in range(len(_SMOOTH))) / sum(_SMOOTH)
        for i in range(BINS)
    ]
    peak = max(range(BINS), key=lambda i: (smooth[i], -i))  # deterministic tie-break
    sx = sum(vx[(peak + d) % BINS] for d in range(-3, 4))
    sy = sum(vy[(peak + d) % BINS] for d in range(-3, 4))
    hue = math.degrees(math.atan2(sy, sx)) % 360.0
    info["peak_bin_deg"] = peak * 5
    return round(hue, 1), info
