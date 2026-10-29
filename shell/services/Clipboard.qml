pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

Singleton {
    id: root

    // [{ id: "123", preview: "…" }], newest first like cliphist
    property var entries: []
    property bool loading: false
    property string error: ""

    function refresh() {
        if (listProc.running) return;
        root.loading = true;
        root.error = "";
        listProc.running = true;
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    if (line.length === 0) continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    out.push({ id: line.slice(0, tab), preview: line.slice(tab + 1) });
                }
                root.entries = out;
                root.loading = false;
                root.thumbnail(out);
            }
        }

        onExited: function(code, status) {
            root.loading = false;
            if (code !== 0) {
                root.entries = [];
                root.error = "cliphist is not available";
            }
        }
    }

    // cliphist lists images as "[[ binary data 120 KiB png 800x600 ]]", decode them once into
    // ~/.cache/noctiluca/clipboard so the launcher can show them
    readonly property string cacheDir: Paths.cacheDir + "/clipboard"
    function imageInfo(preview: string): var {
        const m = /^\[\[ binary data (.+?) (png|jpe?g|gif|webp|bmp) (\d+)x(\d+) \]\]$/.exec(preview);
        return m ? { size: m[1], ext: m[2] === "jpg" ? "jpeg" : m[2], w: Number(m[3]), h: Number(m[4]) } : null;
    }
    function thumbnail(list: var): void {
        const jobs = [];
        for (const e of list.slice(0, 40)) {
            const info = root.imageInfo(e.preview);
            if (!info) continue;
            e.image = "file://" + root.cacheDir + "/" + e.id + "." + info.ext;
            e.info = info;
            jobs.push(e.id + " " + info.ext);
        }
        if (jobs.length === 0) return;
        root.entries = list.slice();
        decoder.command = ["sh", "-c",
            "mkdir -p \"$1\" && shift && while [ $# -gt 1 ]; do f=\"$D/$1.$2\"; [ -s \"$f\" ] || cliphist decode \"$1\" > \"$f\"; shift 2; done",
            "sh", root.cacheDir].concat(jobs.join(" ").split(" "));
        decoder.environment = { D: root.cacheDir };
        decoder.running = true;
    }
    property int decoded: 0          // bumped when the pictures are on disk, so views reload
    Process {
        id: decoder
        onExited: root.decoded++
    }

    function copy(id: string) {
        copyProc.command = ["sh", "-c", "cliphist decode " + JSON.stringify(id) + " | wl-copy"];
        copyProc.running = true;
    }

    function wipe() {
        wipeProc.running = true;
        root.entries = [];
    }

    Process { id: copyProc; running: false }
    Process { id: wipeProc; command: ["cliphist", "wipe"]; running: false }
}
