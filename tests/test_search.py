#!/usr/bin/env python3
"""the launcher's calculator and fuzzy matcher, run as the actual Search.qml in pyside6."""
import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# None = must not count as a calculation
CALC_CASES = [
    ("2+2", 4),
    ("2 + 2", 4),
    ("10/4", 2.5),
    ("2*3+4", 10),
    ("4+2*3", 10),                 # precedence
    ("(4+2)*3", 18),               # brackets
    ("2^10", 1024),
    ("2^3^2", 512),                # right associative: 2^(3^2), not (2^3)^2 = 64
    ("-5+3", -2),                  # unary minus at the start
    ("3*-2", -6),                  # unary minus after an operator
    ("-(3+4)", -7),                # unary minus before a bracket
    ("10%3", 1),
    ("sqrt(16)", 4),
    ("sqrt(16)+1", 5),
    ("round(2.6)", 3),
    ("abs(-7)", 7),
    ("2*pi", 6.283185307179586),
    ("log10(1000)", 3),
    ("1/3", 0.3333333333333333),
    ("((2))", 2),
    ("firefox", None),
    ("", None),
    ("2+", None),
    ("(2+3", None),
    ("2+3)", None),
    ("sqrt", None),                # a function with no argument
    ("2 3", None),                 # two values, no operator
    ("hello world", None),
    ("rm -rf /", None),
    ("1+1; console.log(1)", None),  # no statement injection
    ("[].constructor", None),       # no property access into the engine
]

# (needle, better, worse)
RANK_CASES = [
    ("fox", "Firefox", "Fresh Oxide Xterm"),
    ("term", "Terminal", "Alacritty Terminal Emulator Extended"),
    ("gimp", "GIMP", "Gimp Plugin Registry Browser"),
    ("fi", "Files", "Preferences Dialog Finder"),
]

NO_MATCH = [("zzz", "Firefox"), ("xyz", "Terminal")]

CONVERT_CASES = [
    ("10 km to mi", 6.213711922373339),
    ("1 mi in km", 1.609344),
    ("72 f to c", 22.22222222222222),
    ("100 c to f", 212),
    ("0 c to k", 273.15),
    ("1 gib to mb", 1073.741824),
    ("16 oz to g", 453.59237),
    ("90 min to h", 1.5),
    ("100 km/h to mph", 62.13716227371694),
    ("2 l to cups", 8.333333333333334),
    ("10 km to kg", None),          # different kinds
    ("km to mi", None),             # no number
    ("10 parsecs to mi", None),     # unknown unit
]

HARNESS = """
import QtQuick
import qs.services

QtObject {
    // Serialised in QML: a QML `var` list comes back to Python as a Qt type that json cannot
    // encode, so the harness hands over one plain string instead.
    property string result: ""

    Component.onCompleted: {
        const exprs = %EXPRS%;
        const c = [];
        for (const e of exprs) {
            const v = Search.evaluate(e);
            c.push(v === null || v === undefined ? null : v);
        }
        const pairs = %RANKS%;
        const r = [];
        for (const p of pairs) r.push([Search.score(p[0], p[1]), Search.score(p[0], p[2])]);

        const nm = %NOMATCH%;
        const n = [];
        for (const p of nm) n.push(Search.score(p[0], p[1]));

        const cv = %CONVERT%.map(function(s) { const x = Search.convert(s); return x ? x.result : null; });
        result = JSON.stringify({ calc: c, ranks: r, nomatch: n, convert: cv });
    }
}
"""

PROBE = '''
import sys, json
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent

app = QGuiApplication(sys.argv[:1])
eng = QQmlEngine()
for p in sys.argv[1].split(":"):
    eng.addImportPath(p)
c = QQmlComponent(eng, QUrl.fromLocalFile(sys.argv[2]))
if c.isError():
    print("@@ERR@@" + json.dumps([e.toString() for e in c.errors()]))
    sys.exit(1)
o = c.create()
if o is None:
    print("@@ERR@@" + json.dumps(["component did not instantiate"]))
    sys.exit(1)
print("@@RESULT@@" + o.property("result"))
'''

fails = []


def check(ok, label, detail=""):
    print(f"  [{'PASS' if ok else 'FAIL'}] {label}" + (f"  ({detail})" if detail else ""))
    if not ok:
        fails.append(label)


def main() -> int:
    try:
        import PySide6  # noqa: F401
    except ImportError:
        print("  [SKIP] Search tests (PySide6 not installed)")
        return 0

    spec = importlib.util.spec_from_file_location("rq", ROOT / "tests" / "render_qml.py")
    rq = importlib.util.module_from_spec(spec)
    sys.modules["rq"] = rq
    spec.loader.exec_module(rq)

    tmp = Path(tempfile.mkdtemp(prefix="noct-search-"))
    rq.build_tree(tmp)

    harness = (HARNESS
               .replace("%EXPRS%", json.dumps([e for e, _ in CALC_CASES]))
               .replace("%RANKS%", json.dumps([[n, a, b] for n, a, b in RANK_CASES]))
               .replace("%NOMATCH%", json.dumps([[n, h] for n, h in NO_MATCH]))
               .replace("%CONVERT%", json.dumps([s for s, _ in CONVERT_CASES])))
    (tmp / "harness.qml").write_text(harness)

    r = subprocess.run([sys.executable, "-I", "-c", PROBE, f"{tmp}:{tmp / 'stubs'}",
                        str(tmp / "harness.qml")],
                       capture_output=True, text=True,
                       env={"QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                            "PATH": "/usr/bin:/bin", "HOME": str(tmp), "PYTHONPATH": ""})
    out = r.stdout + r.stderr
    if "@@ERR@@" in out:
        print("  [FAIL] Search.qml did not load:")
        for e in json.loads(out.split("@@ERR@@", 1)[1].splitlines()[0]):
            print("    -", e)
        return 1
    if "@@RESULT@@" not in out:
        print("  [FAIL] harness produced no result")
        print(out.strip()[-1200:])
        return 1
    res = json.loads(out.split("@@RESULT@@", 1)[1].splitlines()[0])

    print("calculator")
    for (expr, expected), got in zip(CALC_CASES, res["calc"]):
        if expected is None:
            check(got is None, f"rejects {expr!r}", f"got {got!r}")
        elif got is None:
            check(False, f"{expr!r} = {expected}", "rejected")
        else:
            check(abs(got - expected) < 1e-9, f"{expr!r} = {expected}", f"got {got!r}")

    print("fuzzy ranking")
    for (needle, better, worse), (sb, sw) in zip(RANK_CASES, res["ranks"]):
        check(sb > sw, f"{needle!r} ranks {better!r} above {worse!r}", f"{sb:.1f} vs {sw:.1f}")
    for (needle, hay), s in zip(NO_MATCH, res["nomatch"]):
        check(s == 0, f"{needle!r} does not match {hay!r}", f"score {s}")

    print("unit conversion")
    for (src, expected), got in zip(CONVERT_CASES, res["convert"]):
        if expected is None:
            check(got is None, f"not a conversion: {src!r}", f"got {got!r}")
        else:
            check(got is not None and abs(got - expected) < 1e-6 * max(1, abs(expected)), f"{src!r} = {expected:g}", f"got {got!r}")

    shutil.rmtree(tmp, ignore_errors=True)
    print()
    if fails:
        print(f"RESULT: {len(fails)} FAILED")
        for f in fails:
            print("  -", f)
        return 1
    print(f"RESULT: all {len(CALC_CASES) + len(RANK_CASES) + len(NO_MATCH) + len(CONVERT_CASES)} search tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
