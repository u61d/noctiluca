pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.core
import qs.components

Singleton {
    id: root

    property bool available: false
    property var recent: []          // newest first: ["#3a8fb7", ...]

    function pick(): void {
        if (!root.available) {
            Notifs.push({ appName: "colour picker", glyph: Icons.colorPicker, summary: "hyprpicker isn't installed",
                          body: "sudo pacman -S hyprpicker", urgency: NotificationUrgency.Normal,
                          expireTimeout: -1, actions: [], image: "", time: new Date(), seen: false });
            return;
        }
        Panels.close();
        later.restart();             // let the panel get out of the picture first
    }
    Timer { id: later; interval: 160; onTriggered: if (!picker.running) picker.running = true }

    function rgb(hex: string): var {
        const n = parseInt(hex.slice(1), 16);
        return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
    }
    function hsl(hex: string): var {
        const c = root.rgb(hex).map(function(v) { return v / 255; });
        const max = Math.max(c[0], c[1], c[2]), min = Math.min(c[0], c[1], c[2]);
        const l = (max + min) / 2;
        let h = 0, s = 0;
        if (max !== min) {
            const d = max - min;
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            h = max === c[0] ? (c[1] - c[2]) / d + (c[1] < c[2] ? 6 : 0)
              : max === c[1] ? (c[2] - c[0]) / d + 2 : (c[0] - c[1]) / d + 4;
            h *= 60;
        }
        return [Math.round(h), Math.round(s * 100), Math.round(l * 100)];
    }
    function forms(hex: string): var {
        const r = root.rgb(hex), h = root.hsl(hex);
        return [hex, "rgb(" + r.join(", ") + ")", "hsl(" + h[0] + ", " + h[1] + "%, " + h[2] + "%)"];
    }

    function copy(text: string): void {
        Quickshell.execDetached(["wl-copy", text]);
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v hyprpicker"]
        onExited: function(code) { root.available = code === 0; }
    }

    Process {
        id: picker
        command: ["hyprpicker", "-f", "hex", "-l", "-b", "-q"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /#[0-9a-fA-F]{6}/.exec(this.text);
                if (!m) return;                    // escape: nothing picked
                const hex = m[0].toLowerCase();
                root.copy(hex);
                root.recent = [hex].concat(root.recent.filter(function(c) { return c !== hex; })).slice(0, 12);
                const f = root.forms(hex);
                Notifs.push({
                    appName: "colour picker", glyph: Icons.colorPicker,
                    summary: hex + " copied",
                    body: f[1] + "\n" + f[2],
                    swatch: hex,
                    urgency: NotificationUrgency.Low, expireTimeout: -1, image: "",
                    actions: [
                        { text: "Copy rgb", invoke: function() { root.copy(f[1]); } },
                        { text: "Copy hsl", invoke: function() { root.copy(f[2]); } }
                    ],
                    time: new Date(), seen: false
                });
            }
        }
    }
}
