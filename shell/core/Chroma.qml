pragma Singleton
import QtQuick
import Quickshell

// port of scripts/lib/noctiluca_color.py, keep the two in sync
Singleton {
    id: root

    function oklchToLinear(L: real, C: real, hDeg: real): var {
        const h = hDeg * Math.PI / 180;
        const a = C * Math.cos(h);
        const b = C * Math.sin(h);
        const l_ = L + 0.3963377774 * a + 0.2158037573 * b;
        const m_ = L - 0.1055613458 * a - 0.0638541728 * b;
        const s_ = L - 0.0894841775 * a - 1.2914855480 * b;
        const l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_;
        return [
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        ];
    }

    function inGamut(rgb: var): bool {
        const e = 1e-4;
        for (let i = 0; i < 3; i++)
            if (rgb[i] < -e || rgb[i] > 1 + e) return false;
        return true;
    }

    // drop chroma until it fits sRGB, lightness and hue stay
    function gamutMap(L: real, C: real, h: real): var {
        let rgb = root.oklchToLinear(L, C, h);
        if (root.inGamut(rgb)) return rgb;
        let lo = 0, hi = C;
        for (let i = 0; i < 24; i++) {
            const mid = (lo + hi) / 2;
            if (root.inGamut(root.oklchToLinear(L, mid, h))) lo = mid; else hi = mid;
        }
        return root.oklchToLinear(L, lo, h);
    }

    function encode(c: real): int {
        const v = Math.min(1, Math.max(0, c));
        const e = v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055;
        return Math.round(e * 255);
    }

    function hex2(n: int): string {
        const s = n.toString(16);
        return s.length < 2 ? "0" + s : s;
    }

    function oklch(L: real, C: real, h: real): color {
        const rgb = root.gamutMap(L, C, h);
        return "#" + root.hex2(root.encode(rgb[0])) + root.hex2(root.encode(rgb[1])) + root.hex2(root.encode(rgb[2]));
    }

    function decode(v8: real): real {
        const c = v8 / 255;
        return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    }

    function toOklch(col: color): var {
        const r = root.decode(col.r * 255), g = root.decode(col.g * 255), b = root.decode(col.b * 255);
        const l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
        const m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
        const s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;
        const l_ = Math.cbrt(l), m_ = Math.cbrt(m), s_ = Math.cbrt(s);
        const L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_;
        const a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_;
        const bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_;
        return { l: L, c: Math.sqrt(a * a + bb * bb), h: ((Math.atan2(bb, a) * 180 / Math.PI) % 360 + 360) % 360 };
    }

    function glowAt(hue: real): color { return root.oklch(0.840, 0.090, hue); }
    function glowHiAt(hue: real): color { return root.oklch(0.940, 0.050, hue); }
    function glowLoAt(hue: real): color { return root.oklch(0.420, 0.060, hue); }
    function monoAt(lightness: real, hue: real): color { return root.oklch(lightness, 0.012, hue); }

    // -1 for greyscale or black art
    function hueFrom(colors: var): real {
        if (!colors || colors.length === 0) return -1;
        let bx = 0, by = 0, total = 0;
        for (let i = 0; i < colors.length; i++) {
            const o = root.toOklch(colors[i]);
            if (o.l < 0.15 || o.l > 0.92 || o.c < 0.03) continue;
            const w = o.c * Math.max(0, 1 - Math.abs(o.l - 0.60) / 0.45);
            if (w <= 0) continue;
            const rad = o.h * Math.PI / 180;
            bx += w * Math.cos(rad);
            by += w * Math.sin(rad);
            total += w;
        }
        if (total <= 0) return -1;
        return ((Math.atan2(by, bx) * 180 / Math.PI) % 360 + 360) % 360;
    }
}
