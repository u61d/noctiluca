#!/usr/bin/env python3
"""Lyrics.qml in a real engine: title cleanup, lookup order, picking a result, lrc parsing.
no network.
"""
import importlib.util
import json
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
import qs.services

Item {
    Component.onCompleted: {
        const r = {
            clean: [
                Lyrics.cleanTitle("Bohemian Rhapsody - Remastered 2011"),
                Lyrics.cleanTitle("Blinding Lights (Official Video)"),
                Lyrics.cleanTitle("Stay (feat. Justin Bieber)"),
                Lyrics.cleanTitle("Ghost ft. Someone"),
                Lyrics.cleanTitle("Plain Title"),
                Lyrics.cleanTitle("Song [HD]")
            ],
            first: [Lyrics.firstArtist("Daft Punk, Pharrell Williams"), Lyrics.firstArtist("Simon & Garfunkel"),
                    Lyrics.firstArtist("Radiohead")],
            guess: Lyrics.guess("Queen - Bohemian Rhapsody (Official Video)", ""),
            plan: Lyrics.plan("Get Lucky - Radio Edit", "Daft Punk, Pharrell Williams", 248.4),
            planExact: Lyrics.plan("Creep", "Radiohead", 238),
            planNone: Lyrics.plan("", "", 0),
            pick: Lyrics.pick([
                { id: 1, duration: 300, plainLyrics: "x" },
                { id: 2, duration: 249, syncedLyrics: "[00:01.00] a" },
                { id: 3, duration: 248, plainLyrics: "y" },
                { id: 4, duration: 248, syncedLyrics: "" }
            ], 248.4),
            pickFar: Lyrics.pick([{ id: 5, duration: 400, syncedLyrics: "[00:01.00] a" }], 248),
            pickGet: Lyrics.pick({ id: 6, syncedLyrics: "[00:01.00] a" }, 0),
            lrc: Lyrics.parseLrc("[ar: x]\\n[00:12.50]one\\n[00:05.00][01:00.00]two\\n")
        };
        console.log("LYR>" + JSON.stringify(r));
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
    tmp = Path(tempfile.mkdtemp(prefix="noct-lyrics-"))
    rq.build_tree(tmp)
    (tmp / "scene.qml").write_text(SCENE)
    probe = ("import sys\nfrom PySide6.QtCore import QUrl\nfrom PySide6.QtGui import QGuiApplication\n"
             "from PySide6.QtQml import QQmlApplicationEngine\napp = QGuiApplication(sys.argv[:1])\n"
             "e = QQmlApplicationEngine()\nfor p in sys.argv[1].split(':'): e.addImportPath(p)\n"
             "e.load(QUrl.fromLocalFile(sys.argv[2]))\nsys.exit(app.exec() if e.rootObjects() else 1)\n")
    env = {"PATH": "/usr/bin:/bin", "HOME": str(tmp), "QT_QPA_PLATFORM": "offscreen",
           "XDG_CONFIG_HOME": str(tmp / "cfg"), "XDG_STATE_HOME": str(tmp / "state")}
    r = subprocess.run([sys.executable, "-I", "-c", probe, f"{tmp}:{tmp / 'stubs'}", str(tmp / "scene.qml")],
                       capture_output=True, text=True, env=env, timeout=120)
    shutil.rmtree(tmp, ignore_errors=True)
    out = None
    for line in (r.stdout + r.stderr).splitlines():
        if "LYR>" in line:
            out = json.loads(line.split("LYR>", 1)[1].rstrip('"'))
    check(out is not None, "Lyrics.qml loads and runs", "" if out else (r.stdout + r.stderr)[-400:])
    if not out:
        return 1

    check(out["clean"] == ["Bohemian Rhapsody", "Blinding Lights", "Stay", "Ghost", "Plain Title", "Song"],
          "titles lose remaster/video/feat. noise", str(out["clean"]))
    check(out["first"] == ["Daft Punk", "Simon", "Radiohead"], "first artist of a list", str(out["first"]))
    check(out["guess"] == {"title": "Bohemian Rhapsody (Official Video)", "artist": "Queen"},
          "a browser title 'Artist - Song' is split", str(out["guess"]))
    plan = out["plan"]
    check(len(plan) == 4 and plan[0].startswith("get?track_name=Get%20Lucky%20-%20Radio%20Edit")
          and "duration=248" in plan[0] and plan[1].startswith("get?track_name=Get%20Lucky&artist_name=Daft%20Punk")
          and plan[2].startswith("search?track_name=Get%20Lucky") and plan[3] == "search?q=Daft%20Punk%20Get%20Lucky",
          "exact lookup first, then cleaned lookup, then searches", str(plan))
    check(len(out["planExact"]) == 3, "nothing to clean: no duplicate lookup", str(out["planExact"]))
    check(out["planNone"] == [], "no title or artist: no requests")
    check(out["pick"] and out["pick"]["id"] == 2, "search: synced lyrics with the closest length win",
          str(out["pick"]))
    check(out["pickFar"] is None, "search: a version 2½ minutes longer is not this song")
    check(out["pickGet"] and out["pickGet"]["id"] == 6, "an exact lookup's single answer is used")
    check(out["lrc"] == [{"t": 5, "text": "two"}, {"t": 12.5, "text": "one"}, {"t": 60, "text": "two"}],
          "LRC: tags skipped, repeated stamps, sorted by time", str(out["lrc"]))

    print()
    if fails:
        print(f"RESULT: {len(fails)} FAILED: {fails}")
        return 1
    print("RESULT: lyrics lookup passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
