#!/usr/bin/env python3
"""renders shell qml to a png with a real qt engine, using the same stubs as load_qml.py and a
bit of fake data. layer-shell attached properties get stripped and fonts may differ.

    python3 tests/render_qml.py preview.qml out.png [--width 1920] [--gpu] [--scene] [--wait=MS]
"""
import importlib.util
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHELL = ROOT / "shell"

FAKE_HYPRLAND = '''pragma Singleton
import QtQuick

QtObject {
    property bool usingLua: true
    property var workspaces: QtObject {
        property var values: [
            { id: 1, name: "1", urgent: false, monitor: null, activate: function(){} },
            { id: 2, name: "2", urgent: false, monitor: null, activate: function(){} },
            { id: 3, name: "3", urgent: false, monitor: null, activate: function(){} },
            { id: 5, name: "5", urgent: true,  monitor: null, activate: function(){} }
        ]
    }
    property var focusedWorkspace: { "id": 3 }
    property var activeToplevel: { "title": "~/noctiluca — zsh", "wayland": { "appId": "kitty" } }
    property var monitors: QtObject { property var values: [] }
    property var toplevels: QtObject { property var values: [] }
    function dispatch(r) {}
    function monitorFor(s) { return null; }
}
'''

PROBE = '''
import sys
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView
app = QGuiApplication(sys.argv[:1])
v = QQuickView()
for p in sys.argv[1].split(":"):
    v.engine().addImportPath(p)
v.setSource(QUrl.fromLocalFile(sys.argv[2]))
if v.status() == QQuickView.Error:
    for e in v.errors():
        print("ERROR", e.toString())
    sys.exit(1)
v.setResizeMode(QQuickView.SizeViewToRootObject)
v.show()
wait = int(sys.argv[4]) if len(sys.argv) > 4 else 0
def grab():
    img = v.grabWindow()
    img.save(sys.argv[3])
    print(f"rendered {img.width()}x{img.height()} -> {sys.argv[3]}")
    app.quit()
if wait > 0:
    from PySide6.QtCore import QTimer
    QTimer.singleShot(wait, grab)
    app.exec()
else:
    grab()
'''


def build_tree(tmp: Path) -> tuple[Path, Path]:
    """Copy shell/ to <tmp>/qs, synthesize qmldir files, and write Quickshell stubs."""
    spec = importlib.util.spec_from_file_location("lq", ROOT / "tests" / "load_qml.py")
    lq = importlib.util.module_from_spec(spec)
    sys.modules["lq"] = lq
    spec.loader.exec_module(lq)

    qs = tmp / "qs"
    shutil.copytree(SHELL, qs)
    for f in qs.rglob("*.qml"):
        text = f.read_text()
        new, _ = lq.strip_attached(text)       # whole statements, continuation lines included
        if new != text:
            f.write_text(new)
    lq.synthesize_qmldir(qs)

    stubs = tmp / "stubs"
    lq.write_stubs(stubs)
    (stubs / "Quickshell" / "Hyprland" / "HyprlandSingleton.qml").write_text(FAKE_HYPRLAND)
    clock = stubs / "Quickshell" / "SystemClock.qml"
    clock.write_text(clock.read_text().replace("property var date", "property var date: new Date()"))
    return qs, stubs


def main() -> int:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    args = [a for a in sys.argv[1:] if not a.startswith("--") and not a.isdigit()]
    gpu = "--gpu" in sys.argv
    scene = "--scene" in sys.argv
    wait = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--wait=")), "0")
    src, out = Path(args[0]).resolve(), Path(args[1]).resolve()
    try:
        import PySide6  # noqa: F401
    except ImportError:
        print("render_qml: PySide6 is required (pip install pyside6)", file=sys.stderr)
        return 2

    tmp = Path(tempfile.mkdtemp(prefix="noct-render-"))
    qs, stubs = build_tree(tmp)
    if scene:
        spec = importlib.util.spec_from_file_location("fx", ROOT / "tests" / "fixtures.py")
        fx = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(fx)
        fx.apply(stubs)
        # PanelWindow anchors are booleans, an Item reads them as anchor lines. strip in scenes
        for f in qs.rglob("*.qml"):
            body = f.read_text()
            new = re.sub(r"^\s*anchors\s*\{\s*(?:(?:top|bottom|left|right)\s*:\s*(?:true|false)\s*;?\s*)+\}\s*$",
                         "", body, flags=re.M)
            if new != body:
                f.write_text(new)
    for f in src.parent.iterdir():
        if f.is_file() and f.suffix in (".qml", ".qsb", ".png", ".jpg", ".webp"):
            shutil.copy(f, tmp / f.name)

    cmd = [sys.executable, "-I", "-c", PROBE, f"{tmp}:{tmp / 'stubs'}",
           str(tmp / src.name), str(out), wait]
    env = {"PATH": "/usr/bin:/bin", "HOME": str(tmp), "PYTHONPATH": ""}
    if gpu:
        # the software scene graph silently skips ShaderEffect. --gpu runs the real gl path on
        # llvmpipe in xvfb
        xvfb = shutil.which("xvfb-run")
        if not xvfb:
            print("render_qml: --gpu needs xvfb-run (and Mesa)", file=sys.stderr)
            return 2
        cmd = [xvfb, "-a", "-s", "-screen 0 2560x1600x24"] + cmd
        env.update({"QT_QPA_PLATFORM": "xcb", "QSG_RHI_BACKEND": "opengl",
                    "LIBGL_ALWAYS_SOFTWARE": "1", "GALLIUM_DRIVER": "llvmpipe"})
    else:
        env.update({"QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"})
    r = subprocess.run(cmd, capture_output=True, text=True, env=env)
    print((r.stdout + r.stderr).strip())
    shutil.rmtree(tmp, ignore_errors=True)
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
