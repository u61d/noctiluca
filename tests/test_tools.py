#!/usr/bin/env python3
"""tests for the test tooling. strip_attached used to drop only the first line of a statement, so
`screen: win.modelData` picked up a stray `? OnDemand : None` and still compiled.
"""
import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("lq", ROOT / "tests" / "load_qml.py")
lq = importlib.util.module_from_spec(spec)
sys.modules["lq"] = lq
spec.loader.exec_module(lq)

fails = []


def check(ok, label, detail=""):
    print(f"  [{'PASS' if ok else 'FAIL'}] {label}" + (f"  ({detail})" if detail else ""))
    if not ok:
        fails.append(label)


CASES = [
    ("one-line statement",
     "    a: 1\n    WlrLayershell.layer: WlrLayer.Top\n    b: 2",
     1, ["a: 1", "b: 2"], ["WlrLayer"]),
    ("two-line ternary does not leak into the line above",
     "    screen: win.modelData\n    WlrLayershell.keyboardFocus: x && y\n        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None\n    c: 3",
     1, ["screen: win.modelData", "c: 3"], ["OnDemand", "None"]),
    ("line ending in an operator continues",
     "    WlrLayershell.namespace: \"a\" +\n        \"b\"\n    d: 4",
     1, ["d: 4"], ['"b"']),
    ("a comment after a statement is kept",
     "    WlrLayershell.layer: WlrLayer.Top\n    // keep me: I am a comment\n    e: 5",
     1, ["// keep me: I am a comment", "e: 5"], ["WlrLayer"]),
    ("consecutive statements are all removed",
     "    WlrLayershell.layer: WlrLayer.Top\n    WlrLayershell.namespace: \"n\"\n    f: 6",
     2, ["f: 6"], ["WlrLayer", '"n"']),
    ("nothing to strip changes nothing",
     "    g: 7\n    h: 8",
     0, ["g: 7", "h: 8"], []),
]


def main() -> int:
    for name, src, n, keep, gone in CASES:
        out, removed = lq.strip_attached(src)
        ok = removed == n and all(k in out for k in keep) and not any(g in out for g in gone)
        check(ok, f"strip_attached: {name}", "" if ok else f"removed {removed}, got:\n{out}")

    check(lq.CPP_TO_QML.get("QQuickItem") == "Item", "QQuickItem bases map to Item stubs")

    print()
    if fails:
        print(f"RESULT: {len(fails)} FAILED: {fails}")
        return 1
    print("RESULT: tooling tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
