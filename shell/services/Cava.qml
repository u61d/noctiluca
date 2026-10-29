pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// want(name)/drop(name) rather than a flag: a panel being replaced can finish dying after
// its replacement asked, and a late "off" would leave the bars flat
Singleton {
    id: root

    property var wantedBy: ({})
    readonly property bool wanted: Object.keys(root.wantedBy).length > 0
    function want(name: string): void {
        const w = Object.assign({}, root.wantedBy);
        w[name] = true;
        root.wantedBy = w;
    }
    function drop(name: string): void {
        if (!(name in root.wantedBy)) return;
        const w = Object.assign({}, root.wantedBy);
        delete w[name];
        root.wantedBy = w;
    }

    readonly property int bars: Settings.player.bars
    readonly property int maxValue: 1000

    property var levels: new Array(Settings.player.bars).fill(0)
    readonly property bool running: proc.running
    property string problem: ""

    readonly property string configPath: Paths.stateDir + "/cava.conf"
    // mono, low to high, instead of cava's mirrored stereo
    readonly property string configBody:
        "[general]\n" +
        "framerate = 60\n" +
        "bars = " + root.bars + "\n" +
        "autosens = 1\n" +
        "[input]\n" +
        "method = pipewire\n" +
        "source = auto\n" +
        "[output]\n" +
        "method = raw\n" +
        "channels = mono\n" +
        "mono_option = average\n" +
        "raw_target = /dev/stdout\n" +
        "data_format = ascii\n" +
        "ascii_max_range = " + root.maxValue + "\n" +
        "bar_delimiter = 59\n" +
        "frame_delimiter = 10\n" +
        "[smoothing]\n" +
        "noise_reduction = 35\n"

    FileView {
        id: configFile
        path: root.configPath
        blockWrites: true       // on disk before cava reads it
        printErrors: true
    }

    property int restarts: 0

    function start(): void {
        if (proc.running) return;
        configFile.setText(root.configBody);
        root.problem = "";
        proc.running = true;
    }

    function stop(): void {
        retry.stop();
        root.restarts = 0;
        proc.running = false;
        root.levels = new Array(root.bars).fill(0);
    }

    onWantedChanged: root.wanted ? root.start() : root.stop()
    onBarsChanged: {
        if (!proc.running) return;
        proc.running = false;
        restartNow.restart();
    }

    Timer { id: restartNow; interval: 50; onTriggered: if (root.wanted) root.start() }

    // cava can lose pipewire (restart, device change), retry a few times
    Timer {
        id: retry
        interval: 1500 * (root.restarts + 1)
        onTriggered: if (root.wanted) root.start()
    }

    Process {
        id: proc
        command: ["cava", "-p", root.configPath]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (!line || line.length === 0) return;
                const parts = line.split(";");
                const out = new Array(root.bars);
                const n = Math.min(root.bars, parts.length);
                for (let i = 0; i < n; i++) {
                    const v = parseInt(parts[i], 10);
                    out[i] = isNaN(v) ? 0 : Math.min(1, v / root.maxValue);
                }
                for (let i = n; i < root.bars; i++) out[i] = 0;
                root.levels = out;
                root.restarts = 0;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t !== "") root.problem = t.split("\n").slice(-2).join(" ");
            }
        }

        onExited: function(code, status) {
            root.levels = new Array(root.bars).fill(0);
            if (!root.wanted) return;
            if (root.problem === "")
                root.problem = "cava stopped (exit " + code + "); is it installed? pacman -S cava";
            console.warn("noctiluca: cava:", root.problem);
            if (root.restarts < 3) {
                root.restarts++;
                retry.restart();
            }
        }
    }

    // a binary that isn't found never "exits"
    Connections {
        target: proc
        function onRunningChanged() {
            if (!proc.running && root.wanted && root.problem === "")
                root.problem = "cava couldn't be started; is it installed? pacman -S cava";
        }
    }

    IpcHandler {
        target: "cava"
        function status(): string {
            return JSON.stringify({ wanted: Object.keys(root.wantedBy), running: proc.running,
                                    problem: root.problem, restarts: root.restarts });
        }
    }
}
