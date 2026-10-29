"""fake data for render_qml.py --scene: a track playing, a sink, a wired connection, some
workspaces with windows. PanelWindow becomes an Item so the real Surface draws into a scene.
"""
from pathlib import Path

ART = "art.png"     # written next to the stubs by write_art()

PANEL_WINDOW = '''import QtQuick

// SCENE FIXTURE: a PanelWindow that is simply an Item, so its contents render in a QQuickView.
Item {
    property var screen: null
    property var mask: null
    property int exclusionMode: 0
    property int exclusiveZone: 0
    property color color: "transparent"
    property var margins: QtObject {
        property int top: 0; property int bottom: 0; property int left: 0; property int right: 0
    }
    width: 1920
    height: 1080
}
'''

FLOATING_WINDOW = '''import QtQuick

// SCENE FIXTURE: a FloatingWindow that is simply an Item.
Item {
    property string title: ""
    property size minimumSize
    property size maximumSize
    property color color: "transparent"
    property var screen: null
    signal closed()
    width: implicitWidth
    height: implicitHeight
    Rectangle { anchors.fill: parent; color: parent.color; z: -1 }
}
'''

POLKIT_AGENT = '''import QtQuick

// SCENE FIXTURE: an agent with one request waiting, so the prompt draws.
QtObject {
    property string path: ""
    property bool isRegistered: true
    property bool isActive: true
    property var flow: QtObject {
        property string message: "Authentication is needed to run `/usr/bin/pacman' as the super user"
        property var selectedIdentity: QtObject { property string displayName: "ana" }
        property bool isResponseRequired: true
        property string inputPrompt: "Password: "
        property bool responseVisible: false
        property string supplementaryMessage: ""
        property bool supplementaryIsError: false
        signal authenticationFailed()
        function submit(v) {}
        function cancelAuthenticationRequest() {}
    }
}
'''

VARIANTS = '''import QtQuick

// SCENE FIXTURE: one instance, for one fake screen at the origin.
Item {
    id: root
    width: 1920; height: 1080
    property var model
    default property Component delegate
    Repeater {
        model: [{ name: "DP-1", x: 0, y: 0, width: 1920, height: 1080 }]
        delegate: root.delegate
    }
}
'''

# `secure` is true, as if the compositor confirmed the lock
SCOPE = '''import QtQuick
Item { width: 1920; height: 1080 }
'''

SESSION_LOCK = '''import QtQuick
Item {
    property bool locked: false
    property bool secure: true
    property var surface: null
    width: 1920; height: 1080
}
'''

SESSION_LOCK_SURFACE = '''import QtQuick
Item {
    property color color: "black"
    property var screen: null
    width: 1920; height: 1080
    Rectangle { anchors.fill: parent; color: parent.color; z: -1 }
}
'''

PIPEWIRE = '''pragma Singleton
import QtQuick

QtObject {
    id: pw
    property bool ready: true
    function node(props) {
        return Qt.createQmlObject('import QtQuick; QtObject { property string description; property string nickname; property string name; '
            + 'property bool isSink; property bool isStream; property var properties: ({}); '
            + 'property var audio: QtObject { property real volume: 0.6; property bool muted: false } }', pw);
    }
    function make(desc, name, sink, stream, props, vol) {
        const n = pw.node();
        n.description = desc; n.name = name; n.isSink = sink; n.isStream = stream;
        n.properties = props || {}; n.audio.volume = vol;
        return n;
    }
    property var scarlett: make("Scarlett 2i2 USB", "alsa_output.usb-Focusrite", true, false, {}, 0.64)
    property var hdmi: make("GP104 High Definition Audio · DELL U2720Q", "alsa_output.pci-hdmi", true, false, {}, 1)
    property var headset: make("WH-1000XM4", "bluez_output.WH-1000XM4", true, false, {}, 0.5)
    property var mic: make("Scarlett 2i2 USB Input", "alsa_input.usb-Focusrite", false, false, {}, 0.8)
    property var spotify: make("Spotify", "spotify", false, true, { "application.name": "Spotify", "application.icon-name": "spotify", "media.name": "Halocline" }, 0.85)
    property var firefox: make("Firefox", "firefox", false, true, { "application.name": "Firefox", "application.icon-name": "firefox", "media.name": "A video about tides — YouTube" }, 0.45)
    property var discordMic: make("Discord", "discord-mic", true, true, { "application.name": "Discord", "application.icon-name": "discord" }, 1)
    property var nodes: QtObject { property var values: [pw.scarlett, pw.hdmi, pw.headset, pw.mic, pw.spotify, pw.firefox, pw.discordMic] }
    property var defaultAudioSink: scarlett
    property var defaultAudioSource: mic
    property var preferredDefaultAudioSink: null
    property var preferredDefaultAudioSource: null
}
'''

SYSTEM_TRAY = '''pragma Singleton
import QtQuick

QtObject {
    id: tray
    function item(name, title) {
        const o = Qt.createQmlObject('import QtQuick; QtObject { property string id; property string title; property string icon; '
            + 'property int status: 1; property bool hasMenu: true; property bool onlyMenu: false; property var menu: null; '
            + 'property string tooltipTitle; function activate() {} function secondaryActivate() {} function scroll(d, h) {} }', tray);
        o.id = name; o.title = title; o.tooltipTitle = title;
        o.icon = Qt.resolvedUrl("../../../icons/" + name + ".svg");
        return o;
    }
    property var items: QtObject { property var values: [tray.item("discord", "Discord"), tray.item("spotify", "Spotify")] }
}
'''

MPRIS = '''pragma Singleton
import QtQuick

QtObject {
    property var players: QtObject {
        property var values: [player]
    }
    property var player: QtObject {
        property string identity: "Spotify"
        property string trackTitle: "Halocline"
        property string trackArtists: "Marrow & Salt"
        property string trackAlbum: "Low Tide"
        property string trackArtUrl: "@ART@"
        property bool isPlaying: true
        property bool canTogglePlaying: true
        property bool canGoNext: true
        property bool canGoPrevious: true
        property bool canSeek: true
        property bool lengthSupported: true
        property bool positionSupported: true
        property real length: 248
        property real position: 94
        property bool shuffleSupported: true
        property bool shuffle: true
        property bool loopSupported: true
        property int loopState: 0
        function togglePlaying() {}
        function next() {}
        function previous() {}
    }
}
'''

NETWORKING = '''pragma Singleton
import QtQuick

QtObject {
    id: nm
    property bool wifiEnabled: true
    property bool wifiHardwareEnabled: true
    property var devices: QtObject {
        property var values: [wired, wifi]
    }
    property var wired: QtObject {
        property int type: DeviceType.Wired
        property bool connected: true
        property string name: "enp5s0"
        property string address: "192.168.1.24"
        property var networks: QtObject { property var values: [] }
    }
    function net(name, s, sec, connected, known) {
        return Qt.createQmlObject('import QtQuick; QtObject { property string name; property real signalStrength; '
            + 'property int security; property bool connected; property bool known; property bool stateChanging: false; '
            + 'signal connectionFailed(int reason); function connect() {} function disconnect() {} function connectWithPsk(p) {} }',
            nm, "net");
    }
    property var wifi: QtObject {
        id: wifi
        property int type: DeviceType.Wifi
        property bool connected: false
        property string name: "wlan0"
        property bool scannerEnabled: true
        property var networks: QtObject {
            property var values: []
        }
    }
    Component.onCompleted: {
        const make = function(name, s, sec, connected, known) {
            const n = net();
            n.name = name; n.signalStrength = s; n.security = sec; n.connected = connected; n.known = known;
            return n;
        };
        wifi.networks.values = [
            make("Kelp Forest", 0.92, WifiSecurityType.Wpa2Psk, false, true),
            make("FRITZ!Box 7590 KQ", 0.71, WifiSecurityType.Wpa2Psk, false, false),
            make("Vodafone Hotspot", 0.45, WifiSecurityType.Open, false, false),
            make("DIRECT-4F-HP Laser", 0.30, WifiSecurityType.Wpa2Psk, false, false),
            make("o2-WLAN58", 0.18, WifiSecurityType.Sae, false, false)
        ];
    }
}
'''

BLUETOOTH = '''pragma Singleton
import QtQuick

QtObject {
    property var defaultAdapter: QtObject { property bool enabled: true; property bool discovering: true }
    property var devices: QtObject {
        property var values: [headphones, mouse, phone, speaker]
    }
    property var headphones: QtObject {
        property string name: "WH-1000XM4"
        property string deviceName: ""
        property bool connected: true
        property bool paired: true
        property bool pairing: false
        property bool trusted: true
        property bool batteryAvailable: true
        property real battery: 0.74
        function connect() {} function disconnect() {} function pair() {} function cancelPair() {}
    }
    property var mouse: QtObject {
        property string name: "MX Master 3S"
        property string deviceName: ""
        property bool connected: false
        property bool paired: true
        property bool pairing: false
        property bool trusted: true
        property bool batteryAvailable: false
        property real battery: 0
        function connect() {} function disconnect() {} function pair() {} function cancelPair() {}
    }
    property var phone: QtObject {
        property string name: "Pixel 9"
        property string deviceName: ""
        property bool connected: false
        property bool paired: false
        property bool pairing: false
        property bool trusted: false
        property bool batteryAvailable: false
        property real battery: 0
        function connect() {} function disconnect() {} function pair() {} function cancelPair() {}
    }
    property var speaker: QtObject {
        property string name: "Boombox 3"
        property string deviceName: ""
        property bool connected: false
        property bool paired: false
        property bool pairing: true
        property bool trusted: false
        property bool batteryAvailable: false
        property real battery: 0
        function connect() {} function disconnect() {} function pair() {} function cancelPair() {}
    }
}
'''

POWER_PROFILES = '''pragma Singleton
import QtQuick

QtObject {
    property int profile: PowerProfile.Balanced
    property bool hasPerformanceProfile: true
}
'''

DESKTOP_ENTRIES = '''pragma Singleton
import QtQuick

QtObject {
    property var applications: QtObject {
        property var values: [
            { id: "firefox", name: "Firefox", genericName: "Web Browser", comment: "", icon: "", keywords: ["web"], noDisplay: false, execute: function() {} },
            { id: "kitty", name: "kitty", genericName: "Terminal", comment: "", icon: "", keywords: ["shell"], noDisplay: false, execute: function() {} },
            { id: "org.gnome.Nautilus", name: "Files", genericName: "File Manager", comment: "", icon: "", keywords: [], noDisplay: false, execute: function() {} },
            { id: "spotify", name: "Spotify", genericName: "Music", comment: "", icon: "", keywords: [], noDisplay: false, execute: function() {} },
            { id: "obsidian", name: "Obsidian", genericName: "Notes", comment: "", icon: "", keywords: [], noDisplay: false, execute: function() {} },
            { id: "steam", name: "Steam", genericName: "Games", comment: "", icon: "", keywords: [], noDisplay: false, execute: function() {} },
            { id: "gimp", name: "GNU Image Manipulation Program", genericName: "Image Editor", comment: "", icon: "", keywords: [], noDisplay: false, execute: function() {} },
            { id: "discord", name: "Discord", genericName: "Chat", comment: "", icon: "", keywords: [], noDisplay: false, execute: function() {} }
        ]
    }
    function byId(id) { return null; }
    function heuristicLookup(name) { return null; }
}
'''

# 1920x1080 monitor at the origin, scale 1
HYPRLAND = '''pragma Singleton
import QtQuick

QtObject {
    id: h
    property bool usingLua: true

    function win(addr, cls, title, x, y, w, ht) {
        return { address: addr, title: title, wayland: { appId: cls },
                 lastIpcObject: { "class": cls, at: [x, y], size: [w, ht] } };
    }
    property var mon: ({ id: 0, name: "DP-1", x: 0, y: 0, width: 1920, height: 1080, scale: 1,
                         activeWorkspace: { id: 3 } })
    property var ws: [
        { id: 1, name: "1", urgent: false, monitor: h.mon, activate: function() {},
          toplevels: { values: [ h.win("a1", "firefox", "Docs", 10, 50, 1900, 1020) ] } },
        { id: 2, name: "2", urgent: false, monitor: h.mon, activate: function() {},
          toplevels: { values: [ h.win("b1", "obsidian", "Notes", 10, 50, 945, 1020),
                                 h.win("b2", "kitty", "zsh", 965, 50, 945, 1020) ] } },
        { id: 3, name: "3", urgent: false, monitor: h.mon, activate: function() {},
          toplevels: { values: [ h.win("c1", "kitty", "nvim", 10, 50, 1200, 1020),
                                 h.win("c2", "kitty", "btop", 1220, 50, 690, 505),
                                 h.win("c3", "spotify", "Spotify", 1220, 565, 690, 505) ] } },
        { id: 4, name: "4", urgent: false, monitor: h.mon, activate: function() {},
          toplevels: { values: [] } },
        { id: 5, name: "5", urgent: true, monitor: h.mon, activate: function() {},
          toplevels: { values: [ h.win("e1", "discord", "Discord", 10, 50, 1900, 1020) ] } }
    ]
    property var workspaces: QtObject { property var values: h.ws }
    property var focusedWorkspace: ({ id: 3 })
    property var focusedMonitor: h.mon
    property var activeToplevel: ({ title: "~/noctiluca — nvim shell/shell.qml", wayland: { appId: "kitty" } })
    property var monitors: QtObject { property var values: [h.mon] }
    property var toplevels: QtObject { property var values: [] }
    function dispatch(r) {}
    function monitorFor(s) { return h.mon; }
    function refreshToplevels() {}
    function refreshWorkspaces() {}
    function refreshMonitors() {}
    signal rawEvent(var event)
}
'''


def write_art(path: Path) -> None:
    """fake cover, a dusk gradient so the art accent has a real colour to find"""
    from PIL import Image, ImageDraw, ImageFilter
    w = h = 400
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / h
        top, mid, bot = (232, 150, 92), (138, 58, 86), (30, 18, 40)
        c = [int(top[i] + (mid[i] - top[i]) * min(1, t / 0.55)) if t < 0.55
             else int(mid[i] + (bot[i] - mid[i]) * (t - 0.55) / 0.45) for i in range(3)]
        d.line([(0, y), (w, y)], fill=tuple(c))
    d.ellipse((150, 120, 250, 220), fill=(250, 214, 160))
    d.rectangle((0, 230, w, h), fill=(26, 16, 34))
    im.filter(ImageFilter.GaussianBlur(1.2)).save(path)


def write_sea(path: Path, w: int = 1920, h: int = 1080) -> None:
    """fake wallpaper, dark water with some caustics"""
    import numpy as np
    from PIL import Image, ImageFilter
    rng = np.random.default_rng(7)

    def fbm(octaves, base):
        out, amp, tot = np.zeros((h, w)), 1.0, 0.0
        for o in range(octaves):
            f = base * 2 ** o
            g = rng.random((f + 1, int(f * w / h) + 2))
            im = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
            out += np.asarray(im, dtype=float) / 255 * amp
            tot += amp
            amp *= 0.55
        return out / tot

    y, x = np.mgrid[0:h, 0:w] / np.array([h, w])[:, None, None]
    n = fbm(6, 4)
    c = (1 - np.abs(np.sin(fbm(5, 3) * 18.0))) ** 10
    light = np.clip(1.2 - np.hypot(x - 0.78, y - 0.05) * 1.3, 0, 1) ** 2
    depth = 0.25 + 0.75 * light
    img = np.stack([0.020 + 0.05 * n * depth + 0.10 * c * light,
                    0.055 + 0.16 * n * depth + 0.30 * c * light,
                    0.070 + 0.20 * n * depth + 0.32 * c * light], -1)
    for _ in range(900):
        px, py = rng.integers(0, w), rng.integers(0, h)
        img[max(0, py - 1):py + 1, max(0, px - 1):px + 1] += np.array([0.10, 0.45, 0.42]) * rng.random() ** 3 * light[py, px] * 2
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8)).save(path)


def write_walls(folder: Path) -> list[str]:
    """a few fake wallpapers for the picker"""
    from PIL import Image, ImageDraw, ImageFilter
    import random
    folder.mkdir(parents=True, exist_ok=True)
    specs = [("ember shoal", (96, 44, 26), (214, 140, 80)), ("fen", (30, 56, 38), (122, 160, 110)),
             ("slate rain", (36, 40, 50), (130, 140, 156)), ("salt flat", (92, 82, 66), (220, 204, 172)),
             ("kelp", (14, 44, 40), (70, 140, 120))]
    out = []
    for i, (name, a, b) in enumerate(specs):
        rnd = random.Random(i)
        im = Image.new("RGB", (640, 360))
        d = ImageDraw.Draw(im)
        for y in range(360):
            t_ = y / 360
            d.line([(0, y), (640, y)], fill=tuple(int(a[k] + (b[k] - a[k]) * t_) for k in range(3)))
        for _ in range(8):
            yy = rnd.randint(150, 340)
            d.line([(0, yy), (640, yy + rnd.randint(-40, 40))], fill=tuple(min(255, c + 25) for c in b), width=2)
        path = folder / f"{name.replace(' ', '_')}.png"
        im.filter(ImageFilter.GaussianBlur(1)).save(path)
        out.append(str(path))
    return out


# real icons where this machine has them, plain tiles otherwise
APPS = {"firefox": "#ff7139", "kitty": "#7f6a4a", "spotify": "#1ed760", "discord": "#5865f2",
        "obsidian": "#7c3aed"}
ICON_SOURCES = [Path("/usr/share/icons/hicolor/scalable/apps"),
                *sorted(Path("/usr").glob("**/material/templates/.icons/simple"))[:1]]


ICON_IMAGE = '''import QtQuick

Item {
    property alias source: img.source
    property alias asynchronous: img.asynchronous
    property alias mipmap: img.mipmap
    property alias status: img.status
    property real implicitSize: 0
    property var actualSize
    property var backer: img
    implicitWidth: implicitSize
    implicitHeight: implicitSize
    Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.max(16, width * 2)
        sourceSize.height: Math.max(16, height * 2)
    }
}
'''


def write_icons(folder: Path) -> None:
    import re
    folder.mkdir(parents=True, exist_ok=True)
    for app, colour in APPS.items():
        svg = None
        for src in ICON_SOURCES:
            f = src / f"{app}.svg"
            if f.is_file():
                svg = f.read_text()
                if "simple" in str(src):
                    svg = re.sub(r"<path ", f'<path fill="{colour}" ', svg)
                break
        if svg is None:
            svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
                   f'<rect x="2" y="2" width="20" height="20" rx="6" fill="{colour}"/></svg>')
        (folder / f"{app}.svg").write_text(svg)


def apply(stubs: Path) -> None:
    """overwrite the generated stubs with these"""
    art = stubs / ART
    write_art(art)
    write_sea(stubs.parent / "sea.png")        # next to the scene file
    write_walls(stubs.parent / "walls")
    files = {
        "Quickshell/PanelWindow.qml": PANEL_WINDOW,
        "Quickshell/FloatingWindow.qml": FLOATING_WINDOW,
        "Quickshell/Variants.qml": VARIANTS,
        "Quickshell/Services/Polkit/PolkitAgent.qml": POLKIT_AGENT,
        "Quickshell/Scope.qml": SCOPE,
        "Quickshell/Wayland/WlSessionLock.qml": SESSION_LOCK,
        "Quickshell/Wayland/WlSessionLockSurface.qml": SESSION_LOCK_SURFACE,
        "Quickshell/Services/Pipewire/PipewireSingleton.qml": PIPEWIRE,
        "Quickshell/Services/SystemTray/SystemTraySingleton.qml": SYSTEM_TRAY,
        "Quickshell/Services/Mpris/MprisSingleton.qml": MPRIS.replace("@ART@", art.as_uri()),
        "Quickshell/Networking/NetworkingSingleton.qml": NETWORKING,
        "Quickshell/Bluetooth/BluetoothSingleton.qml": BLUETOOTH,
        "Quickshell/Services/UPower/PowerProfilesSingleton.qml": POWER_PROFILES,
        "Quickshell/DesktopEntriesSingleton.qml": DESKTOP_ENTRIES,
        "Quickshell/Hyprland/HyprlandSingleton.qml": HYPRLAND,
        "Quickshell/Widgets/IconImage.qml": ICON_IMAGE,
    }
    qs_single = stubs / "Quickshell" / "QuickshellSingleton.qml"
    qs_single.write_text(qs_single.read_text().replace(
        'function env(name) { return ""; }',
        'function env(name) { return name === "USER" || name === "LOGNAME" ? "ana" : ""; }').replace(
        'property string shellDir: ""', 'property string shellDir: "' + str(stubs.parent / "qs") + '"').replace(
        'function iconPath(name) { return ""; }',
        'function iconPath(name, check) { return ' + str(sorted(APPS)).replace("'", '"')
        + '.indexOf(name) >= 0 ? Qt.resolvedUrl("../icons/" + name + ".svg") : ""; }'))
    write_icons(stubs / "icons")
    for rel, src in files.items():
        p = stubs / rel
        if not p.parent.is_dir():
            raise SystemExit(f"fixtures: stub directory missing: {p.parent}")
        p.write_text(src)
