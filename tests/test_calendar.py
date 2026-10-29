#!/usr/bin/env python3
"""runs the real Calendar.qml on an .ics with folded lines, escapes, all-day events, utc times,
weekly repeats, a cancelled date, a count and an end date.
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


ICS = r"""BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
SUMMARY:Dentist\, Dr. Weber
LOCATION:Hauptstr. 4
DTSTART:20261027T081500Z
DTEND:20261027T090000Z
END:VEVENT
BEGIN:VEVENT
SUMMARY:A very long title that the exporter folded onto a sec
 ond line
DTSTART;VALUE=DATE:20261030
DTEND;VALUE=DATE:20261031
END:VEVENT
BEGIN:VEVENT
SUMMARY:Gym
DTSTART;TZID=Europe/Berlin:20261005T180000
DTEND;TZID=Europe/Berlin:20261005T193000
RRULE:FREQ=WEEKLY;BYDAY=MO,TH;UNTIL=20261130T230000Z
EXDATE;TZID=Europe/Berlin:20261029T180000
END:VEVENT
BEGIN:VEVENT
SUMMARY:Standup
DTSTART:20261026T090000
DURATION:PT15M
RRULE:FREQ=DAILY;COUNT=3
END:VEVENT
BEGIN:VEVENT
SUMMARY:Cancelled thing
STATUS:CANCELLED
DTSTART:20261028T100000
END:VEVENT
END:VCALENDAR
"""

SCENE = """import QtQuick
import qs.services

Item {
    Component.onCompleted: {
        const evs = Calendar.parse(%ICS%);
        const from = new Date(2026, 9, 24), to = new Date(2026, 10, 7);
        let occ = [];
        for (const e of evs) occ = occ.concat(Calendar.occurrences(e, from, to));
        occ.sort(function(a, b) { return a.start - b.start; });
        const r = {
            count: evs.length,
            titles: evs.map(function(e) { return e.title; }),
            dentistUtcHour: evs[0].start.getUTCHours(), dentistMinutes: (evs[0].end - evs[0].start) / 60000,
            allDay: evs[1].allDay,
            occ: occ.map(function(o) { return [o.title, o.start.getMonth() + 1, o.start.getDate(), o.start.getHours(), Math.round((o.end - o.start) / 60000)]; })
        };
        console.log("CAL>" + JSON.stringify(r));
        Qt.quit();
    }
}
"""


def main() -> int:
    try:
        import PySide6  # noqa: F401
    except ImportError:
        print("  [SKIP] needs PySide6")
        return 0
    spec = importlib.util.spec_from_file_location("rq", ROOT / "tests" / "render_qml.py")
    rq = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(rq)
    tmp = Path(tempfile.mkdtemp(prefix="noct-cal-"))
    rq.build_tree(tmp)
    (tmp / "scene.qml").write_text(SCENE.replace("%ICS%", json.dumps(ICS)))
    probe = ("import sys\nfrom PySide6.QtCore import QUrl\nfrom PySide6.QtGui import QGuiApplication\n"
             "from PySide6.QtQml import QQmlApplicationEngine\napp = QGuiApplication(sys.argv[:1])\n"
             "e = QQmlApplicationEngine()\nfor p in sys.argv[1].split(':'): e.addImportPath(p)\n"
             "e.load(QUrl.fromLocalFile(sys.argv[2]))\nsys.exit(app.exec() if e.rootObjects() else 1)\n")
    env = {"PATH": "/usr/bin:/bin", "HOME": str(tmp), "QT_QPA_PLATFORM": "offscreen", "TZ": "Europe/Berlin",
           "XDG_CONFIG_HOME": str(tmp / "cfg"), "XDG_STATE_HOME": str(tmp / "state")}
    r = subprocess.run([sys.executable, "-I", "-c", probe, f"{tmp}:{tmp / 'stubs'}", str(tmp / "scene.qml")],
                       capture_output=True, text=True, env=env, timeout=120)
    shutil.rmtree(tmp, ignore_errors=True)
    out = None
    for line in (r.stdout + r.stderr).splitlines():
        if "CAL>" in line:
            out = json.loads(line.split("CAL>", 1)[1].rstrip('"'))
    check(out is not None, "Calendar.qml loads and runs", "" if out else (r.stdout + r.stderr)[-500:])
    if not out:
        return 1

    check(out["count"] == 4, "four events; the cancelled one is dropped", str(out["titles"]))
    check(out["titles"][0] == "Dentist, Dr. Weber", "escaped comma read back", out["titles"][0])
    check(out["titles"][1].endswith("second line"), "folded line joined", out["titles"][1])
    check(out["dentistUtcHour"] == 8 and out["dentistMinutes"] == 45, "UTC time and length", str(out))
    check(out["allDay"] is True, "VALUE=DATE is all-day")
    occ = out["occ"]
    gym = [o for o in occ if o[0] == "Gym"]
    # Mondays and Thursdays from the 24th to before 7 Nov, minus the cancelled 29th
    check([(o[1], o[2]) for o in gym] == [(10, 26), (11, 2), (11, 5)], "weekly on two days, with a date taken out",
          str(gym))
    check(all(o[3] == 18 and o[4] == 90 for o in gym), "each repeat keeps its time and length")
    stand = [o for o in occ if o[0] == "Standup"]
    check([(o[1], o[2]) for o in stand] == [(10, 26), (10, 27), (10, 28)] and stand[0][4] == 15,
          "daily, COUNT=3, length from DURATION", str(stand))

    print()
    if fails:
        print(f"RESULT: {len(fails)} FAILED: {fails}")
        return 1
    print("RESULT: calendar reading passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
