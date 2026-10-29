#!/usr/bin/env python3
"""mutation tests for check_qml.py: inject one qml mistake into a copy of the repo and expect
the checker to fail.
"""
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
fails = []

# (name, file, old, new, expected substring), file None = new file
MUTATIONS = [
    ("property typo on PanelWindow", "shell/modules/surface/Exclusion.qml",
     "exclusiveZone: Tokens.surfaceDepth", "exclusiveZon: Tokens.surfaceDepth", "has no property `exclusiveZon`"),
    ("property typo on a Quickshell singleton type", "shell/core/Theme.qml",
     "watchChanges: true", "watchChange: true", "has no property `watchChange`"),
    ("bad layershell enum value", "shell/modules/surface/Surface.qml",
     "WlrLayershell.layer: WlrLayer.Top", "WlrLayershell.layer: WlrLayer.Topmost", "is not a value of WlrLayer"),
    ("bad keyboard-focus enum", "shell/modules/surface/Surface.qml",
     "? WlrKeyboardFocus.OnDemand", "? WlrKeyboardFocus.Demand", "is not a value of WlrKeyboardFocus"),
    ("attached property typo", "shell/modules/surface/Surface.qml",
     "WlrLayershell.namespace:", "WlrLayershell.namespac:", "is not a property of WlrLayershell"),
    ("singleton with the wrong root type", "shell/core/Motion.qml",
     "Singleton {", "QtObject {", "must be `Singleton`"),
    ("singleton missing the Quickshell import", "shell/core/Paths.qml",
     "import Quickshell", "import QtQuick", "must `import Quickshell`"),
    ("import of a module that does not exist", "shell/shell.qml",
     "import qs.modules.surface", "import qs.modules.surfac", "does not resolve"),
    ("property named `top` (FINAL on Item)", "shell/modules/surface/pools/WindowTitle.qml",
     "readonly property var activeWindow:", "readonly property var top:", "cannot be a property name"),
    ("property shadowing a QtQuick built-in", "shell/components/Slider.qml",
     "property real maximum: 1", "property real maximum: 1\n    property bool enabled: true",
     "shadows the QtQuick property"),
    ("QML syntax error", "shell/components/Icon.qml",
     "import QtQuick.Shapes", "import QtQuick.Shapes @@@", "syntax"),
    ("bad PamResult enum value", "shell/modules/lock/Lock.qml",
     "PamResult.MaxTries", "PamResult.MaxTrys", "is not a value of PamResult"),
    ("bad PamError enum value", "shell/modules/lock/Lock.qml",
     "PamError.StartFailed", "PamError.StartFail", "is not a value of PamError"),
    ("instance re-declares its type's required property", "shell/shell.qml",
     "        Wallpaper {}",
     "        Wallpaper {\n            required property var modelData\n            screen: modelData\n        }",
     "re-declares a required property"),
    ("inline component uses an outer id", "shell/modules/surface/drops/DashboardDrop.qml",
     "        width: parent ? parent.width : 300\n        height: 66", "        width: root.colMachine\n        height: 66",
     "inline component `Gauge` uses `root`"),
    ("id starting with a capital", "shell/modules/wallpaper/Desktop.qml",
     "        id: weeks", "        id: Weeks", "must start with a lowercase"),
    ("a contract layer no window claims", "shell/modules/wallpaper/Desktop.qml",
     "    WlrLayershell.namespace: Tokens.nsDesktop\n", "", "is never claimed by a window"),
    ("a contract shortcut nobody declares", "shell/modules/surface/Shortcuts.qml",
     '    Key { name: "overview"; description: "Noctiluca: overview"; onPressed: Panels.toggle("overview") }\n', "",
     "shortcut `overview` is never declared"),
]


def run(workdir: Path):
    return subprocess.run([sys.executable, "-I", str(workdir / "tests" / "check_qml.py")],
                          capture_output=True, text=True, cwd=workdir)


def fresh(tmp: Path) -> Path:
    work = tmp / "repo"
    if work.exists():
        shutil.rmtree(work)
    shutil.copytree(ROOT, work, ignore=shutil.ignore_patterns("__pycache__", "*.tar.gz", ".git"))
    return work


def check(ok, label, detail=""):
    print(f"  [{'PASS' if ok else 'FAIL'}] {label}" + (f"  ({detail})" if detail else ""))
    if not ok:
        fails.append(label)


def main() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="noct-qml-"))

    base = run(fresh(tmp))
    check(base.returncode == 0, "unmodified shell passes")
    if base.returncode != 0:
        print(base.stdout[-2000:])

    for name, rel, old, new, expect in MUTATIONS:
        work = fresh(tmp)
        f = work / rel
        if not f.exists():
            check(False, f"detects: {name}", f"mutation target file is gone: {rel}")
            continue
        text = f.read_text()
        if old not in text:
            check(False, f"detects: {name}", f"mutation target missing in {rel}: {old!r}")
            continue
        f.write_text(text.replace(old, new, 1))
        r = run(work)
        out = r.stdout + r.stderr
        ok = r.returncode != 0 and expect.lower() in out.lower()
        check(ok, f"detects: {name}", "" if ok else f"expected {expect!r}, exit={r.returncode}")
        if not ok:
            print("         " + "\n         ".join(out.strip().splitlines()[-6:]))

    # false positive guard: a file with an `onError:` handler must still pass the syntax check
    work = fresh(tmp)
    (work / "shell" / "components" / "ErrorBait.qml").write_text(
        'import QtQuick\n\nItem {\n'
        '    signal failed(var arg)\n'
        '    Connections {\n'
        '        target: null\n'
        '        function onError(e) { console.log("Error: not a syntax error"); }\n'
        '    }\n}\n')
    r = run(work)
    out = r.stdout + r.stderr
    check("syntax error" not in out.lower(), "no false positive: a file containing `onError:`",
          "" if "syntax error" not in out.lower() else "reported a syntax error")

    # a hand-written qmldir turns off quickshell's own
    work = fresh(tmp)
    (work / "shell" / "components" / "qmldir").write_text("module qs.components\n")
    r = run(work)
    out = r.stdout + r.stderr
    check(r.returncode != 0 and "qmldir" in out.lower(), "detects: hand-written qmldir")

    print()
    if fails:
        print(f"RESULT: {len(fails)} blind spot(s): {fails}")
        return 1
    print(f"RESULT: checker detected all {len(MUTATIONS) + 1} injected mistakes, with no false positive")
    return 0


if __name__ == "__main__":
    sys.exit(main())
