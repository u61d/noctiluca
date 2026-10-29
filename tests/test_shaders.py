#!/usr/bin/env python3
"""the shaders: .qsb bundles match the sources, the sources compile, and where the gpu path
runs, what they draw is checked pixel by pixel (shapes and fillet for waterline, start, end
and middle for tide). missing tools are SKIP.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHADERS = ROOT / "shell" / "shaders"
fails = []


def check(ok, label, detail=""):
    print(f"  [{'PASS' if ok else 'FAIL'}] {label}" + (f"  ({detail})" if detail else ""))
    if not ok:
        fails.append(label)


def skip(label, why):
    print(f"  [SKIP] {label}  ({why})")


def find_qsb():
    for c in ("/usr/lib/qt6/bin/qsb", shutil.which("qsb6"), shutil.which("qsb")):
        if c and Path(c).is_file():
            return c
    try:
        import PySide6
        c = Path(PySide6.__file__).parent / "qsb"
        return str(c) if c.is_file() else None
    except ImportError:
        return None


# known shapes over magenta, so any coverage shows
WATER_SCENE = '''import QtQuick
Rectangle {
    width: 1200; height: 500
    color: "#ff00ff"
    ShaderEffect {
        anchors.fill: parent
        property size size: Qt.size(width, height)
        property real line: 4
        property real poolBlend: 16
        property real dropBlend: 22
        property real dropRadius: 22
        property vector4d pool0: Qt.vector4d(-60, 300, 40, 18)
        property vector4d pool1: Qt.vector4d(0, 0, 0, 0)
        property vector4d pool2: Qt.vector4d(0, 0, 0, 0)
        property vector4d drop0: Qt.vector4d(600, -22, 400, 322)
        property vector4d drop1: Qt.vector4d(0, 0, 0, 0)
        property color ink: Qt.rgba(0.02, 0.05, 0.05, 1.0)
        property color inkDeep: Qt.rgba(0.01, 0.02, 0.02, 1.0)
        property color glow: Qt.rgba(0.5, 0.87, 0.87, 1.0)
        property point cursor: Qt.point(-1, -1)
        property real rimBase: 0.22
        property real light: 1.0
        property vector4d ripple: Qt.vector4d(0, 1, 0, 0)
        fragmentShader: "waterline.frag.qsb"
    }
}
'''

TIDE_SCENE = '''import QtQuick
Item {
    width: 400; height: 300
    Image { id: a; anchors.fill: parent; source: "old.png"; visible: false }
    Image { id: b; anchors.fill: parent; source: "new.png"; visible: false }
    ShaderEffect {
        anchors.fill: parent
        property size size: Qt.size(width, height)
        property real progress: @P@
        property variant fromTex: a
        property variant toTex: b
        property real fromAspect: 4 / 3
        property real toAspect: 4 / 3
        property color glow: "#000000"
        property color base: "#000000"
        fragmentShader: "tide.frag.qsb"
    }
}
'''


def render(scene_dir: Path, name: str) -> Path | None:
    out = scene_dir / (name + ".png")
    r = subprocess.run([sys.executable, str(ROOT / "tests" / "render_qml.py"), str(scene_dir / (name + ".qml")),
                        str(out), "--gpu", "--wait=2500"], capture_output=True, text=True, timeout=300)
    if r.returncode != 0 or not out.exists():
        print("         " + (r.stdout + r.stderr).strip()[-400:])
        return None
    return out


def is_ink(px) -> bool:
    r, g, b = px[:3]
    return r < 60 and b < 90          # dark; the magenta background has r = b = 255


def is_background(px) -> bool:
    r, g, b = px[:3]
    return r > 200 and b > 200 and g < 60


def main() -> int:
    r = subprocess.run(["bash", str(ROOT / "scripts" / "build-shaders"), "--check"],
                       capture_output=True, text=True)
    check(r.returncode == 0, "shipped .qsb bundles match their sources", (r.stdout + r.stderr).strip()[-120:])

    qsb = find_qsb()
    if not qsb:
        skip("shader sources compile", "no qsb: pacman -S qt6-shadertools, or pip install pyside6")
    else:
        tmp = Path(tempfile.mkdtemp(prefix="noct-qsb-"))
        for src in sorted(SHADERS.glob("*.frag")):
            r = subprocess.run([qsb, "--glsl", "100es,120,150", "--hlsl", "50", "--msl", "12",
                                "-o", str(tmp / (src.name + ".qsb")), str(src)], capture_output=True, text=True)
            check(r.returncode == 0, f"{src.name} compiles", r.stderr.strip()[-160:])

    try:
        import PySide6  # noqa: F401
        from PIL import Image
    except ImportError:
        skip("shader pixel tests", "PySide6 and Pillow are needed")
        return finish()
    if not shutil.which("xvfb-run"):
        skip("shader pixel tests", "xvfb-run is needed for Qt's GPU path")
        return finish()

    work = Path(tempfile.mkdtemp(prefix="noct-shader-px-"))
    shutil.copy(SHADERS / "waterline.frag.qsb", work)
    shutil.copy(SHADERS / "tide.frag.qsb", work)
    (work / "water.qml").write_text(WATER_SCENE)
    png = render(work, "water")
    if png is None:
        check(False, "waterline scene renders")
        return finish()
    im = Image.open(png).convert("RGB")
    px = im.load()

    check(is_ink(px[100, 20]), "inside the left pool is ink", str(px[100, 20]))
    check(is_ink(px[800, 200]), "inside the drop is ink", str(px[800, 200]))
    check(is_ink(px[450, 1]), "the waterline itself is ink, between the shapes", str(px[450, 1]))
    check(is_background(px[450, 300]), "far from every shape: untouched", str(px[450, 300]))
    check(is_background(px[1150, 450]), "below and beside the drop: untouched", str(px[1150, 450]))
    # (597, 7) is outside both shapes, 3px from each. a plain union leaves it empty, a smooth
    # union of radius 22 puts it at smin(3, 3, 22) = 22 - sqrt(2) * 19 = -4.9px
    check(is_ink(px[597, 7]), "the fillet fills the concave corner (smooth union)", str(px[597, 7]))
    edge = px[594, 10]
    check(edge[1] > 60 and edge[0] < 120, "the fillet's edge lies where smin puts it (rim at -0.6 px)", str(edge))
    # 30px from the line, 40 from the drop: past the fillet, mostly magenta
    p = px[560, 34]
    check(not is_ink(p) and p[0] > p[1] + 60, "beyond the fillet radius stays outside", str(p))
    rim, inside = px[800, 299], px[800, 285]
    check(rim[1] > inside[1] + 25, "the rim carries the accent light", f"rim {rim} vs ink {inside}")

    Image.new("RGB", (400, 300), (20, 30, 200)).save(work / "old.png")     # blue
    Image.new("RGB", (400, 300), (220, 120, 20)).save(work / "new.png")    # orange
    shots = {}
    for p_, name in ((0.0, "tide0"), (0.5, "tide5"), (1.0, "tide1")):
        (work / f"{name}.qml").write_text(TIDE_SCENE.replace("@P@", str(p_)))
        out = render(work, name)
        if out is None:
            check(False, f"tide scene renders at {p_}")
            return finish()
        shots[p_] = Image.open(out).convert("RGB").load()

    def blue(c): return c[2] > 150 and c[0] < 80
    def orange(c): return c[0] > 170 and c[2] < 80
    check(blue(shots[0.0][200, 150]), "tide at 0 shows the old image", str(shots[0.0][200, 150]))
    check(orange(shots[1.0][200, 150]), "tide at 1 shows the new image", str(shots[1.0][200, 150]))
    check(orange(shots[0.5][200, 20]) and blue(shots[0.5][200, 285]),
          "tide halfway: new at the top, old at the bottom",
          f"top {shots[0.5][200, 20]} bottom {shots[0.5][200, 285]}")
    return finish()


def finish() -> int:
    print()
    if fails:
        print(f"RESULT: {len(fails)} FAILED: {fails}")
        return 1
    print("RESULT: shader tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
