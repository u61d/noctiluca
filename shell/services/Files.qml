pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// fd if it's there, find otherwise. hidden dirs skipped, first 40 matches only
Singleton {
    id: root

    property var results: []             // [{ path, name, dir, folder }]
    property bool busy: finder.running
    property string asked: ""

    function search(term: string): void {
        const q = term.trim();
        root.asked = q;
        if (q.length < 2) { root.results = []; finder.running = false; return; }
        later.restart();
    }
    Timer {
        id: later
        interval: 160
        onTriggered: {
            if (finder.running) { finder.running = false; later.restart(); return; }
            finder.command = ["sh", "-c",
                "if command -v fd >/dev/null; then fd -i -F -a --max-results 40 --exclude node_modules -- \"$1\" \"$2\";"
                + " else find \"$2\" -maxdepth 7 -not -path '*/.*' -iname \"*$1*\" 2>/dev/null | head -n 40; fi"
                + " | while read -r f; do [ -d \"$f\" ] && printf 'd\\t%s\\n' \"$f\" || printf 'f\\t%s\\n' \"$f\"; done",
                "sh", root.asked, Paths.home];
            finder.running = true;
        }
    }

    Process {
        id: finder
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const path = line.slice(tab + 1).replace(/\/$/, "");
                    const cut = path.lastIndexOf("/");
                    out.push({ path: path, name: path.slice(cut + 1), dir: path.slice(0, cut).replace(Paths.home, "~"),
                               folder: line[0] === "d" });
                }
                // prefix beats contains
                const q = root.asked.toLowerCase();
                out.sort(function(a, b) {
                    return (b.name.toLowerCase().startsWith(q) ? 1 : 0) - (a.name.toLowerCase().startsWith(q) ? 1 : 0)
                        || a.path.length - b.path.length;
                });
                root.results = out;
            }
        }
    }

    function open(path: string): void { Quickshell.execDetached(["xdg-open", path]); }
    function reveal(path: string): void {
        Quickshell.execDetached(["xdg-open", path.slice(0, path.lastIndexOf("/")) || "/"]);
    }
}
