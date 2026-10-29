pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs.core
import qs.components

// gpu-screen-recorder if it's there, else wf-recorder (cpu, no windows)
Singleton {
    id: root

    property string tool: ""                 // "gsr", "wf" or "" (neither installed)
    property bool cpuFallback: false         // gsr takes -fallback-cpu-encoding
    readonly property bool available: root.tool !== ""
    readonly property bool recording: proc.running
    property string file: ""
    property double startedAt: 0
    property int elapsed: 0                  // seconds
    property string mode: ""

    readonly property string dir: {
        const f = Settings.recorder.folder.trim();
        return f === "" ? Paths.home + "/Videos/Recordings" : f.replace(/^~(?=\/|$)/, Paths.home);
    }
    readonly property string clock: {
        const s = root.elapsed, m = Math.floor(s / 60);
        return (m < 10 ? "0" : "") + m + ":" + (s % 60 < 10 ? "0" : "") + (s % 60);
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "if command -v gpu-screen-recorder >/dev/null; then echo gsr; "
                            + "gpu-screen-recorder --help 2>&1 | grep -q fallback-cpu-encoding && echo cpu-fallback; "
                            + "elif command -v wf-recorder >/dev/null; then echo wf; fi; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const words = this.text.trim().split(/\s+/);
                root.tool = words[0] || "";
                root.cpuFallback = words.indexOf("cpu-fallback") >= 0;
            }
        }
    }

    function region(): void {
        if (root.recording) { root.stop(); return; }
        Panels.close();
        Shot.purpose = "record";
        Shot.selecting = true;
    }
    function screen(): void {
        if (root.recording) { root.stop(); return; }
        Panels.close();
        const m = Hyprland.focusedMonitor;
        root.begin("screen", m ? m.name : "", null);
    }
    function window(): void {
        if (root.recording) { root.stop(); return; }
        Panels.close();
        if (root.tool === "gsr") { root.begin("window", "", null); return; }
        active.running = true;          // wf-recorder: the window's rectangle instead
    }
    function recordRect(x: real, y: real, w: real, h: real): void {
        // encoders want even sizes
        const r = { x: Math.round(x), y: Math.round(y), w: Math.round(w) & ~1, h: Math.round(h) & ~1 };
        root.begin("region", "", r);
    }
    function toggle(): void { root.recording ? root.stop() : root.region(); }

    Process {
        id: active
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(this.text);
                    if (w && w.at && w.size) { root.recordRect(w.at[0], w.at[1], w.size[0], w.size[1]); return; }
                } catch (e) {}
                root.screen();
            }
        }
    }

    function audioArg(): string {
        const a = [];
        if (Settings.recorder.systemAudio) a.push("default_output");
        if (Settings.recorder.microphone) a.push("default_input");
        return a.join("|");
    }

    function begin(mode: string, monitor: string, r: var): void {
        if (!root.available || root.recording) return;
        const name = "Recording " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH.mm.ss") + ".mp4";
        root.file = root.dir + "/" + name;
        root.mode = mode;
        let cmd;
        if (root.tool === "gsr") {
            cmd = ["gpu-screen-recorder", "-f", String(Settings.recorder.fps),
                   "-cursor", Settings.recorder.cursor ? "yes" : "no", "-o", root.file];
            if (mode === "region") cmd.push("-w", "region", "-region", r.w + "x" + r.h + "+" + r.x + "+" + r.y);
            else if (mode === "window") cmd.push("-w", "portal");
            else cmd.push("-w", monitor !== "" ? monitor : "screen");
            const a = root.audioArg();
            if (a !== "") cmd.push("-a", a);
            // gpu can't encode (usually an nvidia driver older than the ffmpeg it was built with):
            // fall back to cpu instead of failing, and say so when it saves
            if (root.cpuFallback) cmd.push("-fallback-cpu-encoding", "yes");
        } else {
            cmd = ["wf-recorder", "-f", root.file];
            if (mode === "region") cmd.push("-g", r.x + "," + r.y + " " + r.w + "x" + r.h);
            else if (monitor !== "") cmd.push("-o", monitor);
            if (Settings.recorder.systemAudio || Settings.recorder.microphone) cmd.push("-a");
        }
        const q = function(s) { return "'" + s.replace(/'/g, "'\\''") + "'"; };
        // exec so SIGINT reaches the recorder itself; everything goes to recorder.log for doctor
        root.log = Paths.stateDir + "/recorder.log";
        proc.command = ["sh", "-c", "mkdir -p " + q(root.dir) + " " + q(Paths.stateDir)
                        + " && printf '%s\\n' " + q("$ " + cmd.join(" ")) + " > " + q(root.log)
                        + " && exec " + cmd.map(q).join(" ") + " 2>> " + q(root.log)];
        proc.running = true;
        root.startedAt = Date.now();
        root.elapsed = 0;
    }

    // SIGINT tells both to finish the file
    function stop(): void {
        if (!proc.running) return;
        root.stopping = true;
        proc.signal(2);
    }

    Timer {
        interval: 500
        repeat: true
        running: root.recording
        onTriggered: root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000)
    }

    Process {
        id: proc
        // what matters is whether there's a video. one that died within 2s never started
        onExited: function(code, status) {
            root.exitCode = code;
            root.quick = Date.now() - root.startedAt < 2000 && !root.stopping;
            root.stopping = false;
            saved.command = ["test", "-s", root.file];
            saved.running = true;
        }
    }
    property bool quick: false
    property bool stopping: false
    property int exitCode: 0
    property string log: ""

    Process {
        id: saved
        onExited: function(code) {
            if (code === 0 && !root.quick) {
                root.savedNotice = true;
                why.reload();
            } else {
                root.failedNotice = true;
                why.reload();
            }
            root.mode = "";
        }
    }
    property bool savedNotice: false
    function announceSaved(log: string): void {
        root.savedNotice = false;
        const cpu = /cpu encoding|libx264|nvenc api version/i.test(log);
        const note = cpu ? "\nEncoded on the CPU: the GPU encoder isn't usable with this NVIDIA driver and FFmpeg pair. "
                           + "Updating the driver (or FFmpeg) brings the GPU back." : "";
        Notifs.push({
            appName: "recording", glyph: Icons.record,
                    summary: "Recording saved",
                    body: root.clock + " in " + root.file.replace(Paths.home, "~") + note,
                    urgency: NotificationUrgency.Low, expireTimeout: -1, image: "",
                    actions: [
                        { text: "Play", invoke: function() { Quickshell.execDetached(["xdg-open", root.file]); } },
                        { text: "Show folder", invoke: function() { Quickshell.execDetached(["xdg-open", root.dir]); } }
                    ],
                    time: new Date(), seen: false
                });
    }

    property bool failedNotice: false
    FileView {
        id: why
        path: root.log
        printErrors: false
        onLoaded: {
            if (root.savedNotice) root.announceSaved(this.text());
            else if (root.failedNotice) root.explain(this.text());
        }
        onLoadFailed: {
            if (root.savedNotice) root.announceSaved("");
            else if (root.failedNotice) root.explain("");
        }
    }
    function explain(text: string): void {
        root.failedNotice = false;
        const lines = text.split("\n").filter(function(l) { return l.trim() !== "" && l.indexOf("$ ") !== 0; });
        const errs = lines.filter(function(l) { return /error|fail|unable|cannot|could not|invalid|permission|denied/i.test(l); });
        const said = (errs.length > 0 ? errs.slice(-2) : lines.slice(-2)).join(" ").replace(/^gsr (error|info):\s*/i, "");
        const tool = root.tool === "gsr" ? "gpu-screen-recorder" : "wf-recorder";
        Notifs.push({
            appName: "recording", glyph: Icons.record, summary: "Recording didn't work",
            body: (said !== "" ? said : tool + " stopped with " + root.exitCode)
                  + "\nThe whole log: " + root.log.replace(Paths.home, "~"),
            urgency: NotificationUrgency.Normal, expireTimeout: -1, image: "",
            actions: [{ text: "Open the log", invoke: function() { Quickshell.execDetached(["xdg-open", root.log]); } }],
            time: new Date(), seen: false
        });
    }

    IpcHandler {
        target: "recorder"
        function region(): void { root.region(); }
        function screen(): void { root.screen(); }
        function window(): void { root.window(); }
        function stop(): void { root.stop(); }
        function toggle(): void { root.toggle(); }
    }
}
