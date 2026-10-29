pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// laptops only. external monitors would need ddc
Singleton {
    id: root

    property bool available: false
    property real level: 0
    signal stepped()

    // brightnessctl -m: device,class,current,percent%,max
    function read(text: string): void {
        const f = text.trim().split("\n")[0].split(",");
        if (f.length < 5) return;
        root.available = true;
        root.level = Math.max(0, Math.min(1, Number(f[2]) / Math.max(1, Number(f[4]))));
    }

    function step(percent: int): void {
        if (!root.available) return;
        setter.command = ["brightnessctl", "-m", "-c", "backlight", "-n", "1%", "set",
                          Math.abs(percent) + "%" + (percent > 0 ? "+" : "-")];
        setter.running = true;
    }

    // at most every 60 ms
    property int wanted: -1
    function set(percent: int): void {
        if (!root.available) return;
        root.wanted = Math.max(1, Math.min(100, percent));
        root.level = root.wanted / 100;
        if (!throttle.running) throttle.start();
    }
    Timer {
        id: throttle
        interval: 60
        onTriggered: {
            if (root.wanted < 0 || setter.running) { if (root.wanted >= 0) throttle.restart(); return; }
            setter.command = ["brightnessctl", "-m", "-c", "backlight", "set", root.wanted + "%"];
            root.wanted = -1;
            setter.running = true;
        }
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v brightnessctl >/dev/null && brightnessctl -m -c backlight info"]
        stdout: StdioCollector { onStreamFinished: root.read(this.text) }
    }

    Process {
        id: setter
        stdout: StdioCollector {
            onStreamFinished: {
                root.read(this.text);
                root.stepped();
            }
        }
    }
}
