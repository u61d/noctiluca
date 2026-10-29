#!/usr/bin/env python3
"""static checks for the shell's qml against tests/qs_api.json. quickshell ships no .qmltypes,
so qmllint can't see its types and a typo on a PanelWindow would only show up at runtime.

checks syntax, stray qmldirs, singletons, qs.* imports, properties and enums on known
quickshell types, and the tokens.json contract. unknown types are skipped, not guessed.

    python3 tests/check_qml.py [--qmlformat PATH]
"""
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHELL = ROOT / "shell"
API = json.loads((ROOT / "tests" / "qs_api.json").read_text())
TYPES, BY_CNAME = API["types"], API["by_cname"]
TOKENS = json.loads((ROOT / "design" / "tokens.json").read_text())

# arch's /usr/bin/qmlformat is qt5's and chokes on typed signatures, so take the newest
# qt6 one we can find
def _qmlformat_version(path):
    try:
        env = {**os.environ, "LC_ALL": "C.UTF-8"}
        out = subprocess.run([path, "--version"], capture_output=True, text=True, env=env, timeout=10)
        m = re.search(r"(\d+)\.(\d+)(?:\.(\d+))?", out.stdout + out.stderr)
        return tuple(int(x) for x in m.groups(default="0")) if m else None
    except Exception:
        return None


def _pyside_qmlformat():
    try:
        import PySide6
        cand = Path(PySide6.__file__).parent / "qmlformat"
        return str(cand) if cand.is_file() else None
    except Exception:
        return None


QMLFORMAT = None
QMLFORMAT_VERSION = None
_explicit = (sys.argv[sys.argv.index("--qmlformat") + 1] if "--qmlformat" in sys.argv else None) \
            or os.environ.get("QMLFORMAT")
_candidates = [_explicit] if _explicit else [
    shutil.which("qmlformat6"),
    "/usr/lib/qt6/bin/qmlformat",
    "/usr/lib/qt6/qmlformat",
    _pyside_qmlformat(),
    shutil.which("qmlformat"),          # last: on some distros this is the Qt5 one
]
_best = None
for cand in _candidates:
    if not cand or not Path(cand).is_file():
        continue
    v = _qmlformat_version(cand)
    if not v or v[0] < 6:
        continue                         # Qt5 cannot parse QML 6 type annotations
    if _best is None or v > _best[1]:
        _best = (cand, v)
    if _explicit:
        break
if _best:
    QMLFORMAT, QMLFORMAT_VERSION = _best

fails, warns, skips = [], [], []


def fail(where, msg):
    fails.append(f"{where}: {msg}")


# the quickshell api data stops at qt base classes
QT_COMMON = {
    "id", "objectName", "data", "children", "parent", "x", "y", "z", "width", "height",
    "implicitWidth", "implicitHeight", "anchors", "visible", "opacity", "enabled", "clip",
    "scale", "rotation", "transform", "transformOrigin", "layer", "states", "state",
    "transitions", "focus", "activeFocus", "antialiasing", "smooth", "baselineOffset",
    "containmentMask", "childrenRect", "accessible",
}
QT_ATTACHED = {"Component", "Keys", "Layout", "Accessible", "Qt", "Behavior", "Drag", "ListView", "GridView"}


def resolve(type_name):
    """All properties and signals of a Quickshell type, following its inheritance chain."""
    props, signals, seen = {}, set(), set()
    name = type_name
    while name and name not in seen:
        seen.add(name)
        t = TYPES.get(name) or TYPES.get(BY_CNAME.get(name, ""))
        if not t:
            return (props, signals, False) if not props else (props, signals, True)
        props.update(t["props"])
        signals.update(t["signals"])
        name = t["base"]
    return props, signals, True


def strip_noise(text):
    """Remove comments and string literals so braces/colons inside them don't confuse the scan."""
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    out = []
    for line in text.splitlines():
        line = re.sub(r"(?<!:)//.*$", "", line)          # keep "https://" intact
        line = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
        line = re.sub(r"'(?:[^'\\]|\\.)*'", "''", line)
        out.append(line)
    return "\n".join(out)


def check_file(path: Path):
    rel = path.relative_to(ROOT)
    raw = path.read_text()
    text = strip_noise(raw)

    if re.search(r"^\s*pragma Singleton", raw, re.M):
        root_match = re.search(r"^\s*(\w+)\s*\{", text, re.M)
        if not root_match:
            fail(rel, "pragma Singleton but no root object found")
        elif root_match.group(1) != "Singleton":
            fail(rel, f"pragma Singleton root is `{root_match.group(1)}`, must be `Singleton` "
                      "(Quickshell.Singleton) so reloads propagate")
        if "import Quickshell" not in raw:
            fail(rel, "singleton must `import Quickshell` for the Singleton type")

    # inline components have their own id scope: outer ids compile fine and are undefined at runtime
    all_ids = set(re.findall(r"\bid:\s*(\w+)", text))
    for cm in re.finditer(r"\bcomponent\s+(\w+)\s*:\s*[\w.]+\s*\{", text):
        depth, i = 1, cm.end()
        while i < len(text) and depth:
            depth += {"{": 1, "}": -1}.get(text[i], 0)
            i += 1
        block = text[cm.end():i - 1]
        own = set(re.findall(r"\bid:\s*(\w+)", block))
        for outer in sorted(all_ids - own):
            if re.search(r"(?<![\w.])" + re.escape(outer) + r"\b(?!\s*:)", block):
                line = text[:cm.start()].count("\n") + 1
                fail(rel, f"line {line}: inline component `{cm.group(1)}` uses `{outer}`, an id "
                          f"declared outside it. Inline components have their own id scope: "
                          f"pass it in as a property.")

    for m in re.finditer(r"\bid:\s*([A-Za-z_]\w*)", text):
        if m.group(1)[0].isupper():
            line = text[:m.start()].count("\n") + 1
            fail(rel, f"line {line}: id `{m.group(1)}` must start with a lowercase letter or `_`")

    # top/bottom/left/right are FINAL anchor lines on Item
    for m in re.finditer(r"^\s*(?:readonly\s+)?property\s+[\w<>.]+\s+(top|bottom|left|right)\b",
                         raw, re.M):
        lineno = raw[:m.start()].count("\n") + 1
        fail(rel, f"line {lineno}: `{m.group(1)}` cannot be a property name "
                  "(FINAL anchor line on Item)")

    # redeclaring `enabled` etc. hides qt's own (how Slider looked disabled without being it)
    SHADOWABLE = {"enabled", "visible", "opacity", "clip", "focus", "smooth", "antialiasing",
                  "scale", "rotation", "state", "parent", "children", "activeFocus"}
    # non-visual roots may legitimately use these names
    NON_VISUAL_ROOTS = {"Singleton", "QtObject", "Scope", "ShellRoot", "Component"}
    root_type = re.search(r"^\s*(\w+)\s*\{", text, re.M)
    root_is_visual = not (root_type and root_type.group(1) in NON_VISUAL_ROOTS)
    inline_item_spans = [
        (text[:m.start()].count("\n") + 1, 10 ** 9)
        for m in re.finditer(r"^\s*component\s+\w+\s*:\s*(Item|Rectangle|Text|Image|MouseArea)\s*\{",
                             text, re.M)
    ]
    for m in re.finditer(r"^\s*(?:readonly\s+)?property\s+[\w<>.]+\s+(\w+)", raw, re.M):
        if m.group(1) not in SHADOWABLE:
            continue
        lineno = raw[:m.start()].count("\n") + 1
        inside_inline_item = any(start <= lineno for start, _ in inline_item_spans)
        if root_is_visual or inside_inline_item:
            fail(rel, f"line {lineno}: `{m.group(1)}` shadows the QtQuick property of the same "
                      "name; use the inherited one instead")

    for mod in re.findall(r"^\s*import\s+qs\.([\w.]+)", raw, re.M):
        d = SHELL / Path(*mod.split("."))
        if not d.is_dir():
            fail(rel, f"import qs.{mod} does not resolve to {d.relative_to(ROOT)}/")

    lines = text.splitlines()
    stack = []          # (type_name_or_None, brace_depth_at_open)
    depth = 0
    for lineno, line in enumerate(lines, 1):
        stripped = line.strip()
        opens = line.count("{")
        closes = line.count("}")

        m = re.match(r"^(?:\w+\s*:\s*)?([A-Z]\w*(?:\.\w+)*)\s*\{", stripped)
        if m and opens:
            tname = m.group(1).split(".")[-1]
            stack.append((tname, depth))
        elif opens:
            stack.append((None, depth))

        if stack and not m:
            tname, _ = stack[-1]
            if tname and re.match(r"^[a-zA-Z_]\w*(\.\w+)*\s*:", stripped):
                key = stripped.split(":", 1)[0].strip()
                head = key.split(".")[0]
                if (not re.match(r"^\s*(property|readonly|function|signal|component)\b", stripped)
                        and head not in ("id", "on") and not head.startswith("on")):
                    if head in QT_ATTACHED:
                        pass
                    elif head[0].isupper():
                        at = TYPES.get(head)
                        if at is None:
                            warns.append(f"{rel}:{lineno}: unknown attached type `{head}`")
                        elif not at.get("attached"):
                            fail(rel, f"line {lineno}: `{head}` is not an attached type")
                        else:
                            sub = key.split(".", 1)[1] if "." in key else None
                            props, _, _ = resolve(head)
                            if sub and sub not in props:
                                fail(rel, f"line {lineno}: `{head}.{sub}` is not a property of {head} "
                                          f"(have: {', '.join(sorted(props))})")
                    else:
                        props, signals, resolved = resolve(tname)
                        if resolved and props:
                            known = set(props) | QT_COMMON
                            declared = set(re.findall(r"property\s+[\w<>.]+\s+(\w+)", text))
                            declared |= set(re.findall(r"readonly\s+property\s+[\w<>.]+\s+(\w+)", text))
                            if head not in known and head not in declared:
                                fail(rel, f"line {lineno}: `{tname}` has no property `{head}` "
                                          f"(Quickshell {API['quickshell_version']})")

        for ename, eval_ in re.findall(r"\b([A-Z]\w*)\.([A-Z]\w*)\b", stripped):
            t = TYPES.get(ename)
            if t and "values" in t and eval_ not in t["values"]:
                fail(rel, f"line {lineno}: `{ename}.{eval_}` is not a value of {ename} "
                          f"(have: {', '.join(t['values'])})")

        depth += opens - closes
        while stack and depth <= stack[-1][1]:
            stack.pop()


def main():
    if not SHELL.is_dir():
        print("no shell/ directory yet")
        return 0
    qml_files = sorted(SHELL.rglob("*.qml"))
    print(f"shell QML files: {len(qml_files)}  (API: Quickshell {API['quickshell_version']}, "
          f"{len(TYPES)} types)")

    if QMLFORMAT:
        bad = []
        for f in qml_files:
            r = subprocess.run([QMLFORMAT, "-n", str(f)], capture_output=True, text=True)
            # stderr only, stdout is the formatted file (an `onError:` handler tripped it before)
            out = r.stderr
            # some qt versions only print, some also exit non-zero
            if r.returncode != 0 or "Error:" in out or "Parsed invalid file" in out:
                first = next((l for l in out.splitlines() if "Error" in l), out.strip()[:160])
                bad.append(f"{f.relative_to(ROOT)}: syntax error: {first.strip()[:140]}")
        ver = ".".join(str(x) for x in QMLFORMAT_VERSION) if QMLFORMAT_VERSION else "?"
        print(f"  [{'PASS' if not bad else 'FAIL'}] syntax: all {len(qml_files)} files parse "
              f"(qmlformat {ver})")
        for b in bad:
            fails.append(b)
    else:
        skips.append("syntax (no Qt6 qmlformat found; install qt6-declarative)")
        print("  [SKIP] syntax check: no Qt **6** qmlformat found. A Qt5 qmlformat cannot parse\n"
              "         QML 6 type annotations and would report false errors, so it is not used.")

    stray = [p.relative_to(ROOT) for p in SHELL.rglob("qmldir")]
    print(f"  [{'PASS' if not stray else 'FAIL'}] no hand-written qmldir "
          f"(Quickshell synthesizes them)")
    for s in stray:
        fail(s, "a hand-written qmldir disables qmldir synthesis for its whole directory")

    before = len(fails)
    for f in qml_files:
        check_file(f)
    print(f"  [{'PASS' if len(fails) == before else 'FAIL'}] singleton shape, imports, "
          f"properties and enums against the real API")

    # an instance redeclaring a required property its type already has. compiles fine, and the
    # object never gets created. the black wallpaper bug
    before = len(fails)
    own_required = {}
    for f in qml_files:
        body = strip_noise(f.read_text())
        root = re.search(r"^\s*[A-Z]\w*\s*\{", body, re.M)
        if not root:
            continue
        depth, top = 0, []
        for line in body[root.end():].splitlines():
            if depth == 0:
                m = re.match(r"\s*required\s+property\s+[\w<>.]+\s+(\w+)", line)
                if m:
                    top.append(m.group(1))
            depth += line.count("{") - line.count("}")
            if depth < 0:
                break
        if top:
            own_required[f.stem] = set(top)
    for f in qml_files:
        text = strip_noise(f.read_text())
        for comp, props in own_required.items():
            for m in re.finditer(r"(?<![\w.])" + re.escape(comp) + r"\s*\{", text):
                depth, i = 1, m.end()
                inner_start = i
                while i < len(text) and depth:
                    depth += {"{": 1, "}": -1}.get(text[i], 0)
                    i += 1
                block = text[inner_start:i - 1]
                flat, d = [], 0
                for ch in block:
                    if ch == "{":
                        d += 1
                    elif ch == "}":
                        d -= 1
                    elif d == 0:
                        flat.append(ch)
                for pm in re.finditer(r"required\s+property\s+[\w<>.]+\s+(\w+)", "".join(flat)):
                    if pm.group(1) in props:
                        line = text[:m.start()].count("\n") + 1
                        fail(f"{f.relative_to(ROOT)}:{line}",
                             f"`{comp} {{ required property ... {pm.group(1)} }}` re-declares a "
                             f"required property {comp}.qml already has; the inner one is never "
                             f"set and the object is not created. Use `{comp} {{}}`.")
    print(f"  [{'PASS' if len(fails) == before else 'FAIL'}] no instance shadows a required "
          f"property of its own type")

    # extracting a tarball over an old tree leaves removed files behind. singletons and the
    # entry point are exempt
    names = {f.stem: f for f in qml_files}
    referenced = set()
    for f in qml_files:
        text = strip_noise(f.read_text())
        for other in names:
            if other == f.stem:
                continue
            if re.search(r"\b" + re.escape(other) + r"\s*\{", text) or \
               re.search(r"\b" + re.escape(other) + r"\.", text) or \
               re.search(r"\b" + re.escape(other) + r"\.qml\b", f.read_text()):
                # loaded by url, e.g. Qt.resolvedUrl("drops/ControlDrop.qml")
                referenced.add(other)
    singletons = {f.stem for f in qml_files if re.search(r"^\s*pragma Singleton", f.read_text(), re.M)}
    orphans = sorted(set(names) - referenced - singletons - {"shell"})
    if orphans:
        print(f"  [WARN] {len(orphans)} QML file(s) nothing refers to: {', '.join(orphans)}")
        print("         If they were removed upstream, delete them: extracting a tarball"
              "\n         over an existing tree leaves deleted files behind.")

    sh = TOKENS["shell"]
    # Tokens.qml declares everything, counting it would always pass
    authored = [f for f in qml_files if "GENERATED by scripts/gen-tokens" not in f.read_text()]
    all_text = "\n".join(f.read_text() for f in authored)
    used_ns = [l for l in sh["layers"]
               if f'{sh["appid"]}-{l}' in all_text or f'Tokens.ns{l[0].upper() + l[1:]}' in all_text]
    used_sc = set(re.findall(r'name:\s*"([\w-]+)"', all_text)) & set(sh["shortcuts"])
    unclaimed = sorted(set(sh["layers"]) - set(used_ns))
    undeclared = sorted(set(sh["shortcuts"]) - used_sc)
    ok = not unclaimed and not undeclared
    print(f"  [{'PASS' if ok else 'FAIL'}] contract: {len(used_ns)}/{len(sh['layers'])} layers claimed, "
          f"{len(used_sc)}/{len(sh['shortcuts'])} shortcuts declared")
    for l in unclaimed:
        fail("design/tokens.json", f"layer `{l}` is never claimed by a window (WlrLayershell.namespace)")
    for s in undeclared:
        fail("design/tokens.json", f"shortcut `{s}` is never declared by a GlobalShortcut")

    # the app id is what hyprland's window rules match on (the settings window floats by it)
    for rel, want in (("shell/shell.qml", sh["appid"]), ("greeter/shell.qml", sh["appid"] + "-greeter")):
        f = ROOT / rel
        if f.is_file() and f.read_text().splitlines()[0].strip() != f"//@ pragma AppId {want}":
            fail(rel, f"first line has to be `//@ pragma AppId {want}`")

    print()
    for w in warns:
        print(f"  warning: {w}")
    if fails:
        print(f"RESULT: {len(fails)} problem(s)")
        for f in fails:
            print(f"  - {f}")
        return 1
    print(f"RESULT: QML checks passed"
          + (f" ({len(skips)} skipped: {'; '.join(skips)})" if skips else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
