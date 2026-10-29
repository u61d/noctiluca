pragma Singleton
// needed for the `color` type
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// `void` and `signal` can't be property names, hence surfaceVoid and alert
Singleton {
    id: root

    property var roles: Tokens.defaultRoles
    property real hue: 0
    property bool live: false          // true once palette.json has been read
    property string source: "built-in defaults"

    function role(name: string): color {
        const v = root.roles[name];
        return v !== undefined ? v : "#ff00ff";   // magenta = a role name typo, visible on sight
    }

    readonly property color surfaceVoid: root.role("void")     // behind everything
    readonly property color surfaceInk: root.role("ink")       // panels, bar tabs
    readonly property color surfaceSlate: root.role("slate")   // raised: cards, inputs
    readonly property color surfaceDusk: root.role("dusk")     // hover / pressed

    readonly property color line: root.role("line")
    readonly property color mute: root.role("mute")
    readonly property color dim: root.role("dim")
    readonly property color text: root.role("text")

    // the picker previews a hue here without writing anything, -1 = palette.json
    property real previewHue: -1
    property bool previewMono: false

    // a fixed accent applies here right away, the rest of the desktop catches up when the
    // slider is released
    readonly property real liveHue: root.previewHue >= 0 ? root.previewHue
                                  : Settings.appearance.accent === "fixed" ? Settings.appearance.hue : -1
    readonly property bool liveMono: root.previewHue >= 0 && root.previewMono
    readonly property color glow: root.liveMono ? Chroma.monoAt(0.840, root.liveHue)
                                : root.liveHue >= 0 ? Chroma.glowAt(root.liveHue) : root.role("glow")
    readonly property color glowHi: root.liveMono ? Chroma.monoAt(0.940, root.liveHue)
                                  : root.liveHue >= 0 ? Chroma.glowHiAt(root.liveHue) : root.role("glow_hi")
    readonly property color glowLo: root.liveMono ? Chroma.monoAt(0.420, root.liveHue)
                                  : root.liveHue >= 0 ? Chroma.glowLoAt(root.liveHue) : root.role("glow_lo")

    readonly property color alert: root.role("signal")

    function ansi(name: string, bright: bool): color {
        return root.role(bright ? "ansi_bright_" + name : "ansi_" + name);
    }

    FileView {
        id: paletteFile
        path: Paths.palette
        watchChanges: true

        onFileChanged: this.reload()
        onLoadFailed: function(error) {
            root.live = false;
            root.source = "built-in defaults (" + Paths.palette + ": " + error + ")";
        }
        onLoaded: {
            try {
                const doc = JSON.parse(this.text());
                if (doc.schema !== 1)
                    throw new Error("unsupported schema " + doc.schema);
                if (!doc.roles || !doc.roles.glow)
                    throw new Error("no roles in file");
                root.roles = doc.roles;
                root.hue = doc.hue !== undefined ? doc.hue : 0;
                root.live = true;
                root.source = Paths.palette;
            } catch (e) {
                // keep the old palette rather than show a broken one
                root.live = false;
                root.source = "built-in defaults (" + Paths.palette + " unreadable: " + e.message + ")";
                console.warn("noctiluca: palette.json could not be used:", e.message);
            }
        }
    }
}
