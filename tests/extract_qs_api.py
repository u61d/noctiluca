#!/usr/bin/env python3
"""regenerates tests/qs_api.json from a quickshell source checkout (headers plus the few types
written in qml). re-run it when moving to a new quickshell.

    python3 tests/extract_qs_api.py /path/to/quickshell [--out tests/qs_api.json]
"""
import json
import re
import sys
from pathlib import Path

if len(sys.argv) < 2:
    sys.exit(__doc__)
ROOT = Path(sys.argv[1])
OUT = Path(sys.argv[sys.argv.index("--out") + 1]) if "--out" in sys.argv else Path(__file__).with_name("qs_api.json")

version = re.search(r'project\(quickshell VERSION "([^"]+)"', (ROOT / "CMakeLists.txt").read_text()).group(1)

modules = {}
for md in ROOT.glob("src/**/module.md"):
    m = re.search(r'name\s*=\s*"([^"]+)"', md.read_text())
    if m:
        modules[md.parent] = m.group(1)


def module_for(path: Path) -> str | None:
    """Nearest ancestor directory that declares a module."""
    best, best_len = None, -1
    for d, name in modules.items():
        try:
            path.relative_to(d)
        except ValueError:
            continue
        if len(str(d)) > best_len:
            best, best_len = name, len(str(d))
    # src/core and src/window are the root Quickshell module
    return best or "Quickshell"


types: dict[str, dict] = {}
PROP = re.compile(r"Q_PROPERTY\(\s*([\w:<>*\s]+?)\s+(\w+)\s+(?:READ|MEMBER|BINDABLE)")

for hpp in ROOT.glob("src/**/*.hpp"):
    if "/test/" in str(hpp):
        continue
    text = hpp.read_text(errors="replace")
    mod = module_for(hpp)
    # class bodies, so properties land on the right class. declarations can span lines and
    # list several bases
    for m in re.finditer(r"\bclass\s+(\w+)\s*(?::\s*(?:public|private|protected)\s+([\w:]+)[^{;]*?)?\{",
                         text, re.S):
        cname, base = m.group(1), (m.group(2) or "").split("::")[-1]
        start = m.end()
        nxt = text.find("\nclass ", start)
        body = text[start: nxt if nxt != -1 else len(text)]
        named = re.search(r"QML_NAMED_ELEMENT\((\w+)\)", body)
        element = bool(re.search(r"\bQML_ELEMENT\b", body))
        has_props = "Q_PROPERTY" in body
        if not (named or element or has_props):
            continue
        # no QML_ELEMENT still matters: subclasses inherit the properties (WindowInterface ->
        # PanelWindow)
        qml_name = named.group(1) if named else cname
        props, hidden = {}, set()
        for line in body.splitlines():
            if "Q_PROPERTY" not in line:
                continue
            pm = PROP.search(line)
            if not pm:
                continue
            ptype, pname = pm.group(2), pm.group(1).strip()
            # QSDOC_HIDE only hides from the docs. the really internal ones start with __ and get a
            # .qml wrapper
            if ptype.startswith("__"):
                hidden.add(ptype)
                continue
            props[ptype] = pname
        for ovr in re.finditer(r"QSDOC_PROPERTY_OVERRIDE\(\s*([\w:<>*\s]+?)\s+(\w+)\s+READ", body):
            props.setdefault(ovr.group(2), ovr.group(1).strip())
        signals = []
        for sm in re.finditer(r"signals:(.*?)(?:\n(?:public|private|protected)\b|\Z)", body, re.S):
            signals += re.findall(r"void\s+(\w+)\(", sm.group(1))
        inv = re.findall(r"Q_INVOKABLE\s+[\w:<>*&\s]+?\s(\w+)\(", body)
        enums = re.findall(r"Q_ENUM\((\w+)\)", body)
        entry = types.setdefault(qml_name, {
            "cname": cname, "base": base, "module": mod, "props": {}, "signals": [],
            "functions": [], "enums": [], "hidden": [], "attached": False,
            "instantiable": bool(named or element),
        })
        entry["instantiable"] = entry.get("instantiable", False) or bool(named or element)
        entry["props"].update(props)
        entry["signals"] = sorted(set(entry["signals"] + signals))
        entry["functions"] = sorted(set(entry["functions"] + inv))
        entry["enums"] = sorted(set(entry["enums"] + enums))
        entry["hidden"] = sorted(set(entry["hidden"]) | hidden)
        if re.search(r"QML_ATTACHED\(", body):
            entry["attached"] = True
        if not entry["base"]:
            entry["base"] = base
        if not entry["module"]:
            entry["module"] = mod

for hpp in ROOT.glob("src/**/*.hpp"):
    if "/test/" in str(hpp):
        continue
    text = hpp.read_text(errors="replace")
    for m in re.finditer(r"namespace\s+(\w+)\s*\{\s*//\s*NOLINT(.*?)\n\}\s*//\s*namespace", text, re.S):
        name, body = m.group(1), m.group(2)
        if "QML_ELEMENT" not in body:
            continue
        values = re.findall(r"^\s*(\w+)\s*=\s*\d+", body, re.M)
        types.setdefault(name, {
            "cname": name, "base": "", "module": module_for(hpp), "props": {}, "signals": [],
            "functions": [], "enums": [], "hidden": [], "attached": False, "values": values,
        })

# the other enum shape: a QML_ELEMENT class holding one `enum Enum` (PamResult...). without
# this `PamResult.Succes` slipped through
for hpp in ROOT.glob("src/**/*.hpp"):
    if "/test/" in str(hpp):
        continue
    text = hpp.read_text(errors="replace")
    for m in re.finditer(r"class\s+(\w+)\s*:\s*public\s+QObject\s*\{(.*?)\n\};", text, re.S):
        name, body = m.group(1), m.group(2)
        if "QML_ELEMENT" not in body:
            continue
        em = re.search(r"\benum\s+Enum\b[^{]*\{(.*?)\n\t*\}\s*;", body, re.S)
        if not em:
            continue
        values = re.findall(r"^\s*(\w+)\s*=\s*\d+", em.group(1), re.M)
        if not values:
            continue
        entry = types.setdefault(name, {
            "cname": name, "base": "QObject", "module": module_for(hpp), "props": {},
            "signals": [], "functions": [], "enums": [], "hidden": [], "attached": False,
        })
        entry["values"] = values

for q in ROOT.glob("src/**/*.qml"):
    if "/test/" in str(q):
        continue
    text = q.read_text(errors="replace")
    name = q.stem
    props = {p: t for t, p in re.findall(r"^\s*(?:readonly\s+)?property\s+([\w<>.]+)\s+(\w+)", text, re.M)}
    # aliases are real properties too (ClippingRectangle's color and radius)
    for alias_name in re.findall(   # NOT `name`: that holds the type name (q.stem)
            r"^\s*(?:readonly\s+|default\s+)*property\s+(?:/\*[^*]*\*/\s*)?alias\s+(\w+)",
            text, re.M):
        props.setdefault(alias_name, "alias")
    funcs = re.findall(r"^\s*function\s+(\w+)\s*\(", text, re.M)
    base = re.search(r"^\s*(\w+)\s*\{", text, re.M)
    entry = types.setdefault(name, {
        "cname": name, "base": "", "module": module_for(q), "props": {}, "signals": [],
        "functions": [], "enums": [], "hidden": [], "attached": False,
    })
    entry["props"].update(props)
    entry["functions"] = sorted(set(entry["functions"] + funcs))
    if base and not entry["base"]:
        entry["base"] = base.group(1)

# qml name often differs from the c++ name (WindowInterface is QsWindow)
by_cname = {}
for qml_name, t in types.items():
    by_cname.setdefault(t["cname"], qml_name)

doc = {
    "quickshell_version": version,
    "generated_by": "tests/extract_qs_api.py",
    "by_cname": {k: v for k, v in sorted(by_cname.items())},
    "types": {k: v for k, v in sorted(types.items())},
}
OUT.write_text(json.dumps(doc, indent=1, sort_keys=False) + "\n")
elements = [k for k, v in types.items() if v["module"]]
print(f"wrote {OUT}: quickshell {version}, {len(types)} QML types, {len(elements)} in named modules")
for probe in ("PanelWindow", "FileView", "Variants", "GlobalShortcut", "Singleton", "ShellRoot", "WlrLayershell"):
    t = types.get(probe)
    mod = (t.get("module") or "-") if t else "MISSING"
    base = (t.get("base") or "-") if t else "-"
    print(f"  {probe:16s} module={mod:28s} base={base:22s} props={len(t['props']) if t else 0}")
