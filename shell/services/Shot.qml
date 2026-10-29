pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs.core
import qs.components

Singleton {
    id: root

    property bool selecting: false
    property string purpose: "shot"
    readonly property string dir: Paths.home + "/Pictures/Screenshots"

    function stamp(): string {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd HH.mm.ss");
    }

    // wait for our own panel/overlay to be gone before capturing
    property var pending: null
    Timer {
        id: later
        interval: 180
        onTriggered: {
            const args = root.pending;
            root.pending = null;
            if (args) root.grab(args);
        }
    }
    function soon(args: var): void {
        root.pending = args;
        later.restart();
    }

    function region(): void {
        Panels.close();
        root.purpose = "shot";
        root.selecting = true;
    }

    function screen(): void {
        Panels.close();
        const m = Hyprland.focusedMonitor;
        root.soon(m ? ["-o", m.name] : []);
    }

    function window(): void {
        Panels.close();
        active.running = true;
    }

    function rect(x: real, y: real, w: real, h: real): void {
        root.selecting = false;
        if (w < 2 || h < 2) return;
        if (root.purpose === "record") {
            Recorder.recordRect(x, y, w, h);
            return;
        }
        root.soon(["-g", Math.round(x) + "," + Math.round(y) + " " + Math.round(w) + "x" + Math.round(h)]);
    }

    function cancel(): void { root.selecting = false; }

    Process {
        id: active
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(this.text);
                    if (w && w.at && w.size) {
                        root.soon(["-g", w.at[0] + "," + w.at[1] + " " + w.size[0] + "x" + w.size[1]]);
                        return;
                    }
                } catch (e) {}
                root.screen();
            }
        }
    }

    property string lastFile: ""
    function grab(args: var): void {
        const file = root.dir + "/Screenshot " + root.stamp() + ".png";
        root.lastFile = file;
        const q = function(s) { return "'" + s.replace(/'/g, "'\\''") + "'"; };
        shoot.command = ["sh", "-c", "mkdir -p " + q(root.dir) + " && grim " + args.map(q).join(" ") + " " + q(file)
                         + " && { wl-copy --type image/png < " + q(file) + " || true; }"];
        shoot.running = true;
    }

    Process {
        id: shoot
        stderr: StdioCollector { id: err }
        onExited: function(code) {
            if (code !== 0) {
                Notifs.push({ appName: "screenshot", glyph: Icons.screenshot, summary: "Screenshot failed",
                              body: err.text.trim() || "grim exited with " + code, urgency: NotificationUrgency.Normal,
                              expireTimeout: -1, actions: [], image: "", time: new Date(), seen: false });
                return;
            }
            const file = root.lastFile;
            Notifs.push({
                appName: "screenshot", glyph: Icons.screenshot,
                summary: "Screenshot saved and copied",
                body: file.replace(Paths.home, "~"),
                urgency: NotificationUrgency.Low,
                expireTimeout: -1,
                image: Paths.fileUrl(file),
                actions: [
                    { text: "Open", invoke: function() { Quickshell.execDetached(["xdg-open", file]); } },
                    { text: "Show folder", invoke: function() { Quickshell.execDetached(["xdg-open", root.dir]); } }
                ],
                time: new Date(),
                seen: false
            });
        }
    }
}
