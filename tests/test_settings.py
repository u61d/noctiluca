#!/usr/bin/env python3
"""Settings.qml keeps two copies of the defaults (the adapter and the `defaults` map for reset).
checks they agree, and that every Settings.group.key the shell uses exists.
"""
import importlib.util
import re
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

Item {
    Component.onCompleted: {
        const bad = [];
        const keys = [];
        for (const g in Settings.defaults) {
            for (const k in Settings.defaults[g]) {
                keys.push(g + "." + k);
                const live = Settings[g][k];
                if (JSON.stringify(live) !== JSON.stringify(Settings.defaults[g][k])) bad.push(g + "." + k + ": " + live + " vs " + Settings.defaults[g][k]);
            }
        }
        console.log("KEYS>" + keys.join(","));
        console.log("BAD>" + bad.join(" | "));
        Qt.quit();
    }
}
'''


def main() -> int:
    try:
        import PySide6  # noqa: F401
    except ImportError:
        print("  [SKIP] needs PySide6")
        return 0
    spec = importlib.util.spec_from_file_location("rq", ROOT / "tests" / "render_qml.py")
    rq = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(rq)
    tmp = Path(tempfile.mkdtemp(prefix="noct-settings-"))
    rq.build_tree(tmp)
    (tmp / "s.qml").write_text(SCENE)
    probe = ("import sys\nfrom PySide6.QtCore import QUrl\nfrom PySide6.QtGui import QGuiApplication\n"
             "from PySide6.QtQml import QQmlApplicationEngine\napp = QGuiApplication(sys.argv[:1])\n"
             "e = QQmlApplicationEngine()\nfor p in sys.argv[1].split(':'): e.addImportPath(p)\n"
             "e.load(QUrl.fromLocalFile(sys.argv[2]))\nsys.exit(app.exec() if e.rootObjects() else 1)\n")
    env = {"PATH": "/usr/bin:/bin", "HOME": str(tmp), "QT_QPA_PLATFORM": "offscreen",
           "XDG_CONFIG_HOME": str(tmp / "cfg"), "XDG_STATE_HOME": str(tmp / "state")}
    r = subprocess.run([sys.executable, "-I", "-c", probe, f"{tmp}:{tmp / 'stubs'}", str(tmp / "s.qml")],
                       capture_output=True, text=True, env=env, timeout=120)
    shutil.rmtree(tmp, ignore_errors=True)
    out = r.stdout + r.stderr
    keys = bad = None
    for line in out.splitlines():
        if "KEYS>" in line:
            keys = set(line.split("KEYS>", 1)[1].rstrip('"').split(","))
        if "BAD>" in line:
            bad = line.split("BAD>", 1)[1].rstrip('"').strip()
    check(keys is not None, "Settings loads and lists its keys", "" if keys else out[-400:])
    if keys is None:
        return 1
    check(bad == "", "the reset defaults match the live defaults", bad or "")

    groups = {k.split(".")[0] for k in keys}
    used = set()
    for f in (ROOT / "shell").rglob("*.qml"):
        for m in re.finditer(r"\bSettings\.(\w+)\.(\w+)\b", f.read_text()):
            if m.group(1) not in groups and m.group(1) in ("path", "defaults", "timeFormat", "barTimeFormat"):
                continue
            used.add((m.group(1) + "." + m.group(2), f.relative_to(ROOT)))
    missing = sorted({f"{k} ({f})" for k, f in used if k not in keys})
    check(not missing, f"every Settings.group.key used in the shell exists ({len(used)} uses)", ", ".join(missing))

    print()
    if fails:
        print(f"RESULT: {len(fails)} FAILED: {fails}")
        return 1
    print("RESULT: settings tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
