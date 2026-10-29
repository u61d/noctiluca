pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// the cheap /proc reads run every 2s all the time so the dashboard opens with a minute of
// history. anything that spawns a process only runs while it's open
Singleton {
    id: root

    property bool watching: false
    readonly property int interval: 2000
    readonly property int keep: 60          // samples of history: two minutes

    property string kernel: ""
    property int cores: 0

    FileView {
        path: "/proc/sys/kernel/osrelease"
        onLoaded: root.kernel = this.text().trim()
    }

    // "now", "4m", "2h", "3d"
    function ago(date): string {
        if (!date) return "";
        const s = Math.max(0, (Date.now() - date.getTime()) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    function push(list: var, v: real): var {
        const out = list.length >= root.keep ? list.slice(list.length - root.keep + 1) : list.slice();
        out.push(v);
        return out;
    }

    // all histories tick together so the graphs scroll in step
    signal sampled()

    property real cpu: 0                     // 0..1
    property var cpuHistory: []
    property var _last: null

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const lines = this.text().split("\n");
            const f = lines[0].trim().split(/\s+/).slice(1).map(Number);   // "cpu  user nice system idle iowait ..."
            if (f.length < 4) return;
            if (root.cores === 0)
                root.cores = lines.filter(function(l) { return /^cpu\d+ /.test(l); }).length;
            const idle = f[3] + (f[4] || 0);
            const total = f.reduce(function(a, b) { return a + b; }, 0);
            if (root._last) {
                const dt = total - root._last.total;
                const di = idle - root._last.idle;
                if (dt > 0) root.cpu = Math.min(1, Math.max(0, 1 - di / dt));
            }
            root._last = { total: total, idle: idle };
            root.cpuHistory = root.push(root.cpuHistory, root.cpu);
        }
    }

    property real memTotal: 0                // bytes
    property real memUsed: 0
    readonly property real mem: root.memTotal > 0 ? root.memUsed / root.memTotal : 0
    property var memHistory: []

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            let total = 0, avail = 0;
            for (const line of this.text().split("\n")) {
                const m = line.match(/^(MemTotal|MemAvailable):\s+(\d+)\s*kB/);
                if (!m) continue;
                if (m[1] === "MemTotal") total = Number(m[2]) * 1024;
                else avail = Number(m[2]) * 1024;
            }
            root.memTotal = total;
            root.memUsed = Math.max(0, total - avail);
            root.memHistory = root.push(root.memHistory, root.mem);
        }
    }

    property real rxRate: 0                  // bytes per second
    property real txRate: 0
    property var rxHistory: []
    property var txHistory: []
    property var _net: null

    FileView {
        id: netdev
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0;
            for (const line of this.text().split("\n").slice(2)) {
                const m = line.match(/^\s*([^:]+):\s*(.*)$/);
                if (!m || m[1] === "lo") continue;
                const f = m[2].trim().split(/\s+/).map(Number);
                rx += f[0] || 0;
                tx += f[8] || 0;
            }
            const now = Date.now();
            if (root._net && now > root._net.t) {
                const s = (now - root._net.t) / 1000;
                root.rxRate = Math.max(0, (rx - root._net.rx) / s);
                root.txRate = Math.max(0, (tx - root._net.tx) / s);
            }
            root._net = { rx: rx, tx: tx, t: now };
            root.rxHistory = root.push(root.rxHistory, root.rxRate);
            root.txHistory = root.push(root.txHistory, root.txRate);
        }
    }

    property real cpuTemp: -1                // degrees C; < 0 = unknown
    property string tempPath: ""
    property string drmBusy: ""              // a non-NVIDIA card's gpu_busy_percent, if any

    // hwmonN numbers change between boots, so find it by name
    Process {
        id: findSensors
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do printf 'hwmon %s %s\\n' \"$d\" \"$(cat \"$d/name\" 2>/dev/null)\"; done; "
                            + "for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$f\" ] && printf 'drm %s\\n' \"$f\"; done; true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const prefer = ["coretemp", "k10temp", "zenpower", "cpu_thermal"];
                const found = {};
                for (const line of this.text.split("\n")) {
                    const parts = line.trim().split(" ");
                    if (parts[0] === "hwmon" && parts.length === 3) found[parts[2]] = parts[1];
                    else if (parts[0] === "drm" && root.drmBusy === "") root.drmBusy = parts[1];
                }
                for (const name of prefer) {
                    if (found[name]) {
                        root.tempPath = found[name] + "/temp1_input";
                        return;
                    }
                }
            }
        }
    }

    FileView {
        id: temp
        path: root.tempPath
        onLoaded: {
            const v = Number(this.text().trim());
            root.cpuTemp = isFinite(v) && v > 0 ? v / 1000 : -1;
        }
    }

    property bool hasGpu: false
    property string gpuName: ""
    property real gpu: 0                     // 0..1 utilisation
    property real gpuTemp: -1
    property real gpuMemUsed: 0              // MiB
    property real gpuMemTotal: 0
    property real gpuPower: -1               // W; < 0 = not reported
    property var gpuHistory: []
    property bool nvidia: true               // until nvidia-smi says otherwise

    Process {
        id: smi
        command: ["nvidia-smi",
                  "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw",
                  "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.split("\n")[0].split(",").map(function(s) { return s.trim(); });
                if (f.length < 5) return;
                root.hasGpu = true;
                root.gpuName = f[0].replace(/^NVIDIA\s+/, "");
                root.gpu = Math.min(1, (Number(f[1]) || 0) / 100);
                root.gpuTemp = Number(f[2]);
                root.gpuMemUsed = Number(f[3]) || 0;
                root.gpuMemTotal = Number(f[4]) || 0;
                const p = Number(f[5]);                      // "[N/A]" on some boards -> NaN
                root.gpuPower = isFinite(p) ? p : -1;
                root.gpuHistory = root.push(root.gpuHistory, root.gpu);
            }
        }
        onExited: function(code, status) { if (code !== 0) root.nvidia = false; }
    }
    // a missing nvidia-smi never exits, it just stops
    Connections {
        target: smi
        function onRunningChanged() { if (!smi.running && !root.hasGpu) root.nvidia = false; }
    }

    FileView {
        id: busy
        path: !root.nvidia ? root.drmBusy : ""
        onLoaded: {
            const v = Number(this.text().trim());
            if (!isFinite(v)) return;
            root.hasGpu = true;
            if (root.gpuName === "") root.gpuName = "GPU";
            root.gpu = Math.min(1, v / 100);
            root.gpuHistory = root.push(root.gpuHistory, root.gpu);
        }
    }

    property real diskTotal: 0               // bytes, of /
    property real diskUsed: 0
    readonly property real disk: root.diskTotal > 0 ? root.diskUsed / root.diskTotal : 0

    Process {
        id: df
        command: ["df", "-B1", "--output=size,used", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                if (lines.length < 2) return;
                const f = lines[1].trim().split(/\s+/).map(Number);
                root.diskTotal = f[0] || 0;
                root.diskUsed = f[1] || 0;
            }
        }
    }

    Timer {
        running: true
        interval: root.interval
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            netdev.reload();
            if (root.watching) {
                if (root.tempPath !== "") temp.reload();
                if (Settings.dashboard.gpu) {
                    if (root.nvidia && !smi.running) smi.running = true;
                    else if (!root.nvidia && root.drmBusy !== "") busy.reload();
                }
            }
            root.sampled();
        }
    }
    Timer {
        running: root.watching
        interval: 60000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!df.running) df.running = true
    }

    function bytes(n: real): string {
        const u = ["B", "K", "M", "G", "T"];
        let i = 0;
        while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
        return (n >= 100 || i === 0 ? n.toFixed(0) : n.toFixed(1)) + u[i];
    }
    // "0", "840 K", "12.4 M"
    function rate(n: real): string {
        if (n < 1024) return "0";
        const u = ["K", "M", "G"];
        let i = -1;
        while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
        return (n >= 100 ? n.toFixed(0) : n.toFixed(1)) + " " + u[i];
    }
}
