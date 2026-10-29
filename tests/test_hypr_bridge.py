#!/usr/bin/env python3
"""runs the qml that writes the settings app's hyprland options, then loads the whole hyprland
config with that output through hl_harness.lua.

    python3 tests/test_hypr_bridge.py --lua /path/to/lua5.5 [--stubs hl.meta.lua]
"""
import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
fails = []


def check(ok, label, detail=""):
    print(f"  [{'PASS' if ok else 'FAIL'}] {label}" + (f"  ({detail})" if detail else ""))
    if not ok:
        fails.append(label)


SCENE = '''import QtQuick
import qs.core
import qs.services

Item {
    Component.onCompleted: {
        @SETUP@
        console.log("LUA>" + "return { anim_speed = " + HyprSettings.lua(Settings.hypr.animationSpeed)
                    + ", config = " + HyprSettings.lua(HyprSettings.configTable()) + " }");
        Qt.quit();
    }
}
'''

VARIANTS = {
    "defaults": "",
    "everything changed": (
        'Settings.hypr.gapsIn = 0; Settings.hypr.gapsOut = 20; Settings.hypr.border = 3; '
        'Settings.hypr.rounding = 0; Settings.hypr.dimInactive = false; Settings.hypr.dimStrength = 0.33; '
        'Settings.hypr.shadow = false; Settings.hypr.glow = false; Settings.hypr.blur = false; '
        'Settings.hypr.animations = false; Settings.hypr.animationSpeed = 1.7; '
        'Settings.hypr.kbLayout = "us,de"; Settings.hypr.kbVariant = ","; Settings.hypr.kbOptions = "grp:alt_shift_toggle"; '
        'Settings.hypr.repeatRate = 50; Settings.hypr.repeatDelay = 200; Settings.hypr.sensitivity = -0.4; '
        'Settings.hypr.accelProfile = "adaptive"; Settings.hypr.naturalScroll = false; '
        'Settings.hypr.tapToClick = false; Settings.hypr.followMouse = 2;'
    ),
}


def lua_for(setup: str) -> str | None:
    spec = importlib.util.spec_from_file_location("rq", ROOT / "tests" / "render_qml.py")
    rq = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(rq)
    tmp = Path(tempfile.mkdtemp(prefix="noct-bridge-"))
    rq.build_tree(tmp)
    scene = tmp / "bridge.qml"
    scene.write_text(SCENE.replace("@SETUP@", setup))
    probe = ("import sys\nfrom PySide6.QtCore import QUrl\nfrom PySide6.QtGui import QGuiApplication\n"
             "from PySide6.QtQml import QQmlApplicationEngine\napp = QGuiApplication(sys.argv[:1])\n"
             "e = QQmlApplicationEngine()\nfor p in sys.argv[1].split(':'): e.addImportPath(p)\n"
             "e.load(QUrl.fromLocalFile(sys.argv[2]))\nsys.exit(app.exec() if e.rootObjects() else 1)\n")
    env = {"PATH": "/usr/bin:/bin", "HOME": str(tmp), "QT_QPA_PLATFORM": "offscreen",
           "XDG_CONFIG_HOME": str(tmp / "cfg"), "XDG_STATE_HOME": str(tmp / "state")}
    r = subprocess.run([sys.executable, "-I", "-c", probe, f"{tmp}:{tmp / 'stubs'}", str(scene)],
                       capture_output=True, text=True, env=env, timeout=120)
    shutil.rmtree(tmp, ignore_errors=True)
    for line in (r.stdout + r.stderr).splitlines():
        if "LUA>" in line:
            return line.split("LUA>", 1)[1].rstrip('"').strip()
    print("         " + (r.stdout + r.stderr).strip()[-600:])
    return None


def main() -> int:
    args = sys.argv[1:]
    lua = args[args.index("--lua") + 1] if "--lua" in args else shutil.which("lua5.5")
    stubs = ["--stubs", args[args.index("--stubs") + 1]] if "--stubs" in args else []
    try:
        import PySide6  # noqa: F401
    except ImportError:
        print("  [SKIP] needs PySide6")
        return 0
    if not lua:
        print("  [SKIP] needs Lua 5.5")
        return 0

    for name, setup in VARIANTS.items():
        text = lua_for(setup)
        check(text is not None and text.startswith("return {"), f"{name}: the shell produces a Lua table")
        if not text:
            continue
        work = Path(tempfile.mkdtemp(prefix="noct-bridge-hl-"))
        cfg = work / "hypr"
        shutil.copytree(ROOT / "config" / "hypr", cfg)
        state = work / "state" / "noctiluca"
        state.mkdir(parents=True)
        (state / "hypr.lua").write_text(text + "\n")
        env = dict(os.environ, XDG_STATE_HOME=str(work / "state"), HOME=str(work))
        r = subprocess.run([lua, str(ROOT / "tests" / "hl_harness.lua"), str(cfg), "--strict"] + stubs,
                           capture_output=True, text=True, env=env, timeout=120)
        check(r.returncode == 0, f"{name}: Hyprland's config accepts every key it sets",
              "" if r.returncode == 0 else (r.stdout + r.stderr).strip()[-500:])
        shutil.rmtree(work, ignore_errors=True)

    print()
    if fails:
        print(f"RESULT: {len(fails)} FAILED: {fails}")
        return 1
    print("RESULT: settings -> Hyprland bridge passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
