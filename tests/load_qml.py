#!/usr/bin/env python3
"""compiles every shell qml file with a real qt engine (pyside6), against quickshell stubs
generated from tests/qs_api.json and qmldirs like the ones quickshell makes at runtime.
catches the startup errors ("color is not a type", unknown properties) before a real run.

    python3 tests/load_qml.py [--keep]
"""
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHELL = ROOT / "shell"
API = json.loads((ROOT / "tests" / "qs_api.json").read_text())
TYPES, BY_CNAME = API["types"], API["by_cname"]

# unmapped types become `var`; the stubs only need the names right
TYPEMAP = {
    "QString": "string", "bool": "bool", "qint32": "int", "int": "int", "quint32": "int",
    "qreal": "real", "double": "real", "float": "real", "QColor": "color", "QDateTime": "var",
    "QVariant": "var", "QQmlComponent*": "Component", "QObject*": "QtObject",
    "QUrl": "url", "QByteArray": "var", "QVariantHash": "var", "QList<QString>": "var",
}

WANTED = {
    "Quickshell": ["Singleton", "ShellRoot", "Scope", "Variants", "LazyLoader", "PanelWindow",
                   "FloatingWindow", "SystemClock", "ColorQuantizer", "Region", "QsMenuOpener"],
    "Quickshell.Services.SystemTray": ["SystemTrayItem"],
    "Quickshell.Services.Greetd": [],
    "Quickshell.Io": ["FileView", "Process", "SplitParser", "StdioCollector", "IpcHandler",
                      "JsonAdapter", "JsonObject"],
    "Quickshell.Hyprland": ["GlobalShortcut", "HyprlandFocusGrab"],
    "Quickshell.Wayland": ["WlrLayershell", "WlSessionLock", "WlSessionLockSurface", "ScreencopyView",
                           "IdleInhibitor", "IdleMonitor"],
    "Quickshell.Services.Polkit": ["PolkitAgent", "AuthFlow", "Identity"],
    "Quickshell.Services.Mpris": ["MprisPlayer"],
    "Quickshell.Services.Pipewire": ["PwObjectTracker", "PwNode", "PwNodeAudio"],
    "Quickshell.Services.Notifications": ["NotificationServer", "Notification", "NotificationAction"],
    "Quickshell.Services.UPower": ["UPowerDevice"],
    "Quickshell.Services.Pam": ["PamContext"],
    "Quickshell.Bluetooth": ["BluetoothAdapter", "BluetoothDevice"],
    "Quickshell.Networking": ["NetworkDevice", "WifiDevice", "WifiNetwork", "Network"],
    "Quickshell.Widgets": ["ClippingRectangle", "ClippingWrapperRectangle", "IconImage",
                           "WrapperItem", "WrapperRectangle", "WrapperMouseArea"],
}

# singletons read through a global name, and enum holders
MANUAL = {
    "Quickshell": {
        "QsMenuButtonType.qml": ("QsMenuButtonType 1.0 QsMenuButtonType.qml", """import QtQuick

QtObject { enum Enum { None, CheckBox, RadioButton } }
"""),
        "DesktopEntriesSingleton.qml": ("singleton DesktopEntries 1.0 DesktopEntriesSingleton.qml",
                                        """pragma Singleton
import QtQuick

QtObject {
    property var applications: QtObject {
        property var values: [
            { name: "Firefox", genericName: "Web Browser", keywords: ["www"], noDisplay: false,
              execute: function(){} },
            { name: "kitty", genericName: "Terminal", keywords: [], noDisplay: false,
              execute: function(){} }
        ]
    }
    function byId(id) { return null; }
    function heuristicLookup(name) { return null; }
}
"""),
    },
    "Quickshell.Services.Greetd": {
        "GreetdSingleton.qml": ("singleton Greetd 1.0 GreetdSingleton.qml", """pragma Singleton
import QtQuick

QtObject {
    property bool available: true
    property int state: 0
    property string user: ""
    signal authMessage(string message, bool error, bool responseRequired, bool echoResponse)
    signal authFailure(string message)
    signal readyToLaunch()
    signal launched()
    signal error(string error)
    function createSession(user) {}
    function cancelSession() {}
    function respond(response) {}
    function launch(command, environment, quit) {}
}
"""),
        "GreetdState.qml": ("GreetdState 1.0 GreetdState.qml", """import QtQuick

QtObject { enum Enum { Inactive, Authenticating, ReadyToLaunch, Launching, Launched } }
"""),
    },
    "Quickshell.Services.SystemTray": {
        "SystemTraySingleton.qml": ("singleton SystemTray 1.0 SystemTraySingleton.qml", """pragma Singleton
import QtQuick

QtObject {
    property var items: QtObject { property var values: [] }
}
"""),
        "Status.qml": ("Status 1.0 Status.qml", """import QtQuick

QtObject { enum Enum { Passive, Active, NeedsAttention } }
"""),
    },
    "Quickshell.Services.Pipewire": {
        "PipewireSingleton.qml": ("singleton Pipewire 1.0 PipewireSingleton.qml", """pragma Singleton
import QtQuick

QtObject {
    property bool ready: true
    property var nodes: QtObject { property var values: [] }
    property var defaultAudioSink: null
    property var defaultAudioSource: null
    property var preferredDefaultAudioSink: null
    property var preferredDefaultAudioSource: null
}
"""),
    },
    "Quickshell.Services.Notifications": {
        "NotificationUrgency.qml": ("NotificationUrgency 1.0 NotificationUrgency.qml", """import QtQuick

QtObject { enum Enum { Low, Normal, Critical } }
"""),
    },
    "Quickshell.Services.UPower": {
        "UPowerSingleton.qml": ("singleton UPower 1.0 UPowerSingleton.qml", """pragma Singleton
import QtQuick

QtObject {
    property var displayDevice: null
    property var devices: QtObject { property var values: [] }
    property bool onBattery: false
}
"""),
        "PowerProfilesSingleton.qml": ("singleton PowerProfiles 1.0 PowerProfilesSingleton.qml", """pragma Singleton
import QtQuick

QtObject {
    property int profile: 1
    property bool hasPerformanceProfile: true
    property var holds: []
}
"""),
        "PowerProfile.qml": ("PowerProfile 1.0 PowerProfile.qml", """import QtQuick

QtObject { enum Enum { PowerSaver, Balanced, Performance } }
"""),
    },
    "Quickshell.Bluetooth": {
        "BluetoothSingleton.qml": ("singleton Bluetooth 1.0 BluetoothSingleton.qml", """pragma Singleton
import QtQuick

QtObject {
    property var defaultAdapter: null
    property var adapters: QtObject { property var values: [] }
    property var devices: QtObject { property var values: [] }
}
"""),
    },
    "Quickshell.Networking": {
        "NetworkingSingleton.qml": ("singleton Networking 1.0 NetworkingSingleton.qml", """pragma Singleton
import QtQuick

QtObject {
    property var devices: QtObject { property var values: [] }
    property int backend: 1
    property bool wifiEnabled: true
    property bool wifiHardwareEnabled: true
    property int connectivity: 4
}
"""),
        "DeviceType.qml": ("DeviceType 1.0 DeviceType.qml", """import QtQuick

QtObject { enum Enum { Unknown, Wifi, Wired } }
"""),
    },
    "Quickshell.Services.Mpris": {
        "MprisSingleton.qml": ("singleton Mpris 1.0 MprisSingleton.qml", """pragma Singleton
import QtQuick

QtObject {
    property var players: QtObject { property var values: [] }
}
"""),
        "MprisPlaybackState.qml": ("MprisPlaybackState 1.0 MprisPlaybackState.qml", """import QtQuick

QtObject { enum Enum { Stopped, Playing, Paused } }
"""),
        "MprisLoopState.qml": ("MprisLoopState 1.0 MprisLoopState.qml", """import QtQuick

QtObject { enum Enum { None, Track, Playlist } }
"""),
    },
}

GROUPED = {
    "anchors": ["bool top", "bool bottom", "bool left", "bool right"],
    "margins": ["int top", "int bottom", "int left", "int right"],
}

SINGLETON_STUBS = {
    "Quickshell": """pragma Singleton
import QtQuick

QtObject {
    property var screens: []
    property string configDir: ""
    property string dataDir: ""
    property string stateDir: ""
    property string shellDir: ""
    property string clipboardText: ""
    function env(name) { return ""; }
    function iconPath(name) { return ""; }
    function execDetached(cmd) {}
    function reload(hard) {}
}
""",
    "Hyprland": """pragma Singleton
import QtQuick

QtObject {
    property bool usingLua: true
    property var workspaces: []
    property var monitors: []
    property var toplevels: []
    property var focusedWorkspace: null
    property var focusedMonitor: null
    property var activeToplevel: null
    function dispatch(request) {}
    function refreshWorkspaces() {}
}
""",
}


def resolve_props(name):
    """Every property of a type, following its inheritance chain."""
    props, seen = {}, set()
    while name and name not in seen:
        seen.add(name)
        t = TYPES.get(name) or TYPES.get(BY_CNAME.get(name, ""))
        if not t:
            break
        for p, ctype in t["props"].items():
            props.setdefault(p, ctype)
        name = t["base"]
    return props


def resolve_sigs(name):
    """Signals and invokable functions, following the inheritance chain. FileView is declared in
    QML over a C++ `FileViewInternal`, so its signals are only found by walking the chain."""
    sigs, funcs, seen = set(), set(), set()
    allprops = set(resolve_props(name)) | {"data"} | set(GROUPED)
    while name and name not in seen:
        seen.add(name)
        t = TYPES.get(name) or TYPES.get(BY_CNAME.get(name, ""))
        if not t:
            break
        for x in t["signals"]:
            if x.startswith("on"):
                continue                       # internal slots picked up by the extractor
            # only drop `<prop>Changed` when the property exists. `fileChanged` is a real signal
            if x.endswith("Changed") and x[: -len("Changed")] in allprops:
                continue
            sigs.add(x)
        funcs |= set(t["functions"])
        name = t["base"]
    return sigs, funcs


QT_VISUAL_BASES = {"Item", "Rectangle", "Image", "Text", "MouseArea"}
# ScreencopyView derives from QQuickItem directly and needs `anchors`
CPP_TO_QML = {"QQuickItem": "Item", "QQuickRectangle": "Rectangle", "QQuickImage": "Image",
              "QQuickText": "Text", "QQuickMouseArea": "MouseArea"}

# reserved words can't be declared in a stub (Notification has `transient`).
# check_qml.py still validates them against the real api
QML_RESERVED = {
    "transient", "synchronized", "abstract", "boolean", "byte", "char", "class", "const",
    "debugger", "double", "enum", "export", "extends", "final", "float", "goto", "implements",
    "import", "in", "instanceof", "int", "interface", "let", "long", "native", "package",
    "private", "protected", "public", "short", "static", "super", "switch", "throws",
    "volatile", "with", "function", "property", "signal", "readonly", "default", "alias",
}


def stub_for(qml_name):
    props = resolve_props(qml_name)
    # FileView has a `loaded` property and a `loaded()` signal. qml can't declare both, the
    # signal wins
    sig_names, fn_names = resolve_sigs(qml_name)
    props = {k: v for k, v in props.items() if k not in sig_names}
    base = (TYPES.get(qml_name) or {}).get("base", "")
    base = CPP_TO_QML.get(base, base)
    visual = base in QT_VISUAL_BASES
    if visual:
        lines = ["import QtQuick", "", f"{base} {{", ""]
    else:
        lines = ["import QtQuick", "", "QtObject {", "    default property list<QtObject> data", ""]
    # only skip what the base actually has. Item has no `color` (broke ClippingRectangle)
    item_props = {"data", "children", "anchors", "width", "height", "x", "y", "z",
                  "opacity", "visible", "enabled", "clip", "scale", "rotation", "parent",
                  "implicitWidth", "implicitHeight", "state", "states", "transitions",
                  "transform", "smooth", "antialiasing", "focus", "activeFocus"}
    provided = {
        "Item": item_props,
        "Rectangle": item_props | {"color", "radius", "border", "gradient"},
        "Image": item_props | {"source", "sourceSize", "fillMode", "status", "asynchronous", "cache"},
        "Text": item_props | {"text", "font", "color", "elide", "wrapMode", "horizontalAlignment"},
        "MouseArea": item_props | {"hoverEnabled", "acceptedButtons", "cursorShape", "containsMouse"},
    }
    QT_ITEM_PROVIDED = provided.get(base, item_props)
    for p, ctype in sorted(props.items()):
        if p in GROUPED:
            continue
        if p == "data" or (visual and p in QT_ITEM_PROVIDED) or p in QML_RESERVED:
            continue
        qtype = TYPEMAP.get(ctype.strip(), "var")
        lines.append(f"    property {qtype} {p}")
    for g, fields in GROUPED.items():
        if g in props and not visual:
            lines.append(f"    property {g.capitalize()}Group {g}: {g.capitalize()}Group {{}}")
    for sig in sorted(s for s in sig_names if s not in QML_RESERVED):
        lines.append(f"    signal {sig}(var arg)")
    for fn in sorted(fn_names - sig_names):
        lines.append(f"    function {fn}() {{}}")
    vals = (TYPES.get(qml_name) or {}).get("values")
    if vals:
        lines.append("    enum Enum { %s }" % ", ".join(vals))
    lines.append("}")
    body = "\n".join(lines)
    for g, fields in GROUPED.items():
        if g in props and not visual:
            decl = "    component %sGroup: QtObject { %s }" % (
                g.capitalize(), " ".join(f"property {f};" for f in fields))
            body = body.replace("    default property list<QtObject> data",
                                "    default property list<QtObject> data\n" + decl, 1)
    return body


def write_stubs(dest: Path):
    for module, names in WANTED.items():
        d = dest / Path(*module.split("."))
        d.mkdir(parents=True, exist_ok=True)
        entries = []
        for n in names:
            if n not in TYPES:
                continue
            (d / f"{n}.qml").write_text(stub_for(n))
            entries.append(f"{n} 1.0 {n}.qml")
        for ename, t in TYPES.items():
            if "values" not in t or t.get("module") != module:
                continue
            # SystemClock is both instantiable and an enum holder; overwriting its stub with the bare
            # enum made `precision` vanish
            if ename in names:
                continue
            vals = ", ".join(t["values"])
            (d / f"{ename}.qml").write_text(
                f"import QtQuick\n\nQtObject {{ enum Enum {{ {vals} }} }}\n")
            entries.append(f"{ename} 1.0 {ename}.qml")
        for fname, (entry, src) in MANUAL.get(module, {}).items():
            (d / fname).write_text(src)
            entries.append(entry)
        for sname, src in SINGLETON_STUBS.items():
            if module == "Quickshell" and sname == "Quickshell":
                (d / "QuickshellSingleton.qml").write_text(src)
                entries.append("singleton Quickshell 1.0 QuickshellSingleton.qml")
            elif module == "Quickshell.Hyprland" and sname == "Hyprland":
                (d / "HyprlandSingleton.qml").write_text(src)
                entries.append("singleton Hyprland 1.0 HyprlandSingleton.qml")
        (d / "qmldir").write_text(f"module {module}\n" + "\n".join(entries) + "\n")


_CONT_START = ("?", ":", "&&", "||", "+", "-", "*", "/", ".", ")", "]", "}")
_CONT_END = ("&&", "||", "?", ":", "+", "-", "*", "/", "(", "[", ",", "=")


def strip_attached(text: str, prefix: str = "WlrLayershell") -> tuple[str, int]:
    """Remove every `<prefix>.name: value` STATEMENT, including any continuation lines.

    Removing only the first line is wrong, and silently so: in
        screen: win.modelData
        WlrLayershell.keyboardFocus: win.hosting && Panels.wantsKeyboard
                                     ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    the dangling `? ... : ...` attaches itself to the line ABOVE, so `screen` becomes
    `win.modelData ? OnDemand : None` (that is: 2). Everything still parses and compiles; the
    surface just thinks it is on another monitor."""
    lines = text.split("\n")
    out, removed, i = [], 0, 0
    head = re.compile(r"^\s*" + re.escape(prefix) + r"\.\w+\s*:")
    while i < len(lines):
        if not head.match(lines[i]):
            out.append(lines[i])
            i += 1
            continue
        removed += 1
        prev = lines[i].rstrip()
        i += 1
        while i < len(lines):
            s = lines[i].strip()
            # `//` starts with `/` but a comment never continues a statement
            if s and not s.startswith(("//", "/*")) and (s.startswith(_CONT_START) or prev.endswith(_CONT_END)):
                prev = lines[i].rstrip()
                i += 1
                continue
            break
    return "\n".join(out), removed


def synthesize_qmldir(qs_root: Path):
    """Mirror Quickshell's qmldir synthesis (src/core/scan.cpp)."""
    for d in [qs_root, *[p for p in qs_root.rglob("*") if p.is_dir()]]:
        qml = sorted(p for p in d.glob("*.qml"))
        if not qml:
            continue
        rel = d.relative_to(qs_root.parent)
        module = ".".join(rel.parts)
        lines = [f"module {module}"]
        for f in qml:
            singleton = "singleton " if re.search(r"^\s*pragma Singleton", f.read_text(), re.M) else ""
            lines.append(f"{singleton}{f.stem} 1.0 {f.name}")
        (d / "qmldir").write_text("\n".join(lines) + "\n")


PROBE = '''
import sys, json
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent

app = QGuiApplication(sys.argv[:1])
eng = QQmlEngine()
for p in sys.argv[1].split(":"):
    eng.addImportPath(p)

problems = []
for f in sys.argv[2:]:
    c = QQmlComponent(eng, QUrl.fromLocalFile(f))
    if c.isError():
        for e in c.errors():
            problems.append({"file": f, "line": e.line(), "col": e.column(), "msg": e.description()})
print("@@RESULT@@" + json.dumps(problems))
'''


def main() -> int:
    try:
        import PySide6  # noqa: F401
    except ImportError:
        print("  [SKIP] QML load test (PySide6 not installed: pip install pyside6)")
        return 0

    keep = "--keep" in sys.argv
    tmp = Path(tempfile.mkdtemp(prefix="noct-load-"))
    qs_root = tmp / "qs"
    shutil.copytree(SHELL, qs_root)

    # attached properties can't be declared from qml, strip the layershell lines in this copy
    stripped = 0
    for f in qs_root.rglob("*.qml"):
        text = f.read_text()
        new, n = strip_attached(text)
        if n:
            stripped += n
            f.write_text(new)

    synthesize_qmldir(qs_root)
    stubs = tmp / "stubs"
    write_stubs(stubs)

    # stubs have to compile on their own. an older version called the cascade "noise" and
    # passed while hiding a real error
    stub_files = sorted(str(p) for p in stubs.rglob("*.qml"))
    rs = subprocess.run([sys.executable, "-I", "-c", PROBE, f"{tmp}:{stubs}", *stub_files],
                        capture_output=True, text=True,
                        env={"QT_QPA_PLATFORM": "offscreen", "PATH": "/usr/bin:/bin",
                             "HOME": str(tmp), "PYTHONPATH": ""})
    if "@@RESULT@@" in rs.stdout:
        bad_stubs = json.loads(rs.stdout.split("@@RESULT@@", 1)[1])
        if bad_stubs:
            print(f"  [FAIL] {len(bad_stubs)} error(s) in the generated STUBS "
                  f"(a defect in tests/load_qml.py, not in the shell):")
            for b in bad_stubs[:8]:
                print(f"    - {Path(b['file']).name}:{b['line']}  {b['msg']}")
            return 1

    files = sorted(str(p) for p in qs_root.rglob("*.qml"))
    r = subprocess.run([sys.executable, "-I", "-c", PROBE, f"{tmp}:{stubs}", *files],
                       capture_output=True, text=True,
                       env={"QT_QPA_PLATFORM": "offscreen", "PATH": "/usr/bin:/bin",
                            "HOME": str(tmp), "PYTHONPATH": ""})
    marker = "@@RESULT@@"
    if marker not in r.stdout:
        print("  [FAIL] QML load test could not run")
        print((r.stdout + r.stderr).strip()[-1500:])
        return 1
    problems = json.loads(r.stdout.split(marker, 1)[1])

    # one broken file takes its module down; report root causes, summarise the rest
    roots, cascade = {}, set()
    for p in problems:
        rel = Path(p["file"]).relative_to(qs_root)
        if p["line"] > 0:
            roots.setdefault((p["line"], p["col"], p["msg"]), set()).add(str(rel))
        else:
            cascade.add(p["msg"])

    print(f"  QML load test: {len(files)} files compiled with Qt "
          f"{__import__('PySide6').__version__} ({stripped} layershell attached lines stripped)")
    if problems:
        print(f"  [FAIL] {len(roots)} root cause(s), {len(problems)} total message(s):")
        for (line, col, msg), where in sorted(roots.items()):
            src = sorted(where)[0] if len(where) == 1 else f"{len(where)} files"
            print(f"    - line {line}:{col}  {msg}")
            print(f"      (reported via {src})")
        if cascade:
            print(f"    + {len(cascade)} knock-on 'type unavailable' message(s) from the same cause")
    else:
        print("  [PASS] every shell QML file compiles")

    if keep:
        print(f"  (kept: {tmp})")
    else:
        shutil.rmtree(tmp, ignore_errors=True)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
