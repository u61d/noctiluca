pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

Singleton {
    id: root

    readonly property string mode: Settings.appearance.accent
    readonly property real hue: Settings.appearance.hue
    readonly property string bin: Paths.home + "/.local/bin/"
    property bool ready: false

    onModeChanged: if (root.ready) settle.restart()
    onHueChanged: if (root.ready && root.mode === "fixed") settle.restart()

    Timer {
        id: settle
        interval: 700
        onTriggered: {
            const palette = root.mode === "fixed"
                ? "'" + root.bin + "noctiluca-palette' --hue " + Math.round(root.hue)
                : "'" + root.bin + "noctiluca-palette' --image \"$('" + root.bin + "noctiluca-wallpaper' --current)\"";
            rebuild.command = ["sh", "-c", palette + " && '" + root.bin + "noctiluca-theme'"];
            rebuild.running = true;
        }
    }

    Process {
        id: rebuild
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim() !== "") console.warn("noctiluca: palette:", this.text.trim())
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: root.ready = true
    }
}
