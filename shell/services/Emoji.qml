pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

Singleton {
    id: root

    property var all: []                 // [[emoji, name, keywords, group]]
    property var groups: []
    property var recent: []              // emoji, newest first
    readonly property bool ready: root.all.length > 0

    FileView {
        path: Quickshell.shellDir + "/data/emoji.json"
        onLoaded: {
            try {
                const d = JSON.parse(this.text());
                root.groups = d.groups;
                root.all = d.emoji;
            } catch (e) { console.warn("noctiluca: emoji.json unreadable:", e.message); }
        }
    }
    FileView {
        id: recentFile
        path: Paths.stateDir + "/emoji-recent.json"
        printErrors: false
        onLoaded: { try { root.recent = JSON.parse(this.text()); } catch (e) {} }
    }

    function search(term: string, limit: int): var {
        const q = term.trim().toLowerCase();
        if (q === "") {
            const seen = {}, out = [];
            for (const e of root.recent) { seen[e] = true; const row = root.all.find(function(r) { return r[0] === e; }); if (row) out.push(row); }
            for (const r of root.all) { if (out.length >= limit) break; if (!seen[r[0]]) out.push(r); }
            return out.slice(0, limit);
        }
        const scored = [];
        for (const r of root.all) {
            let s = Search.score(q, r[1]);
            if (r[2]) for (const w of r[2].split(" ")) s = Math.max(s, Search.score(q, w) * 0.7);
            if (s <= 0) continue;
            const ri = root.recent.indexOf(r[0]);
            if (ri >= 0) s += 30 - ri;
            scored.push({ r: r, s: s });
        }
        scored.sort(function(a, b) { return b.s - a.s; });
        return scored.slice(0, limit).map(function(x) { return x.r; });
    }

    function use(e: string): void {
        Quickshell.execDetached(["wl-copy", e]);
        root.recent = [e].concat(root.recent.filter(function(x) { return x !== e; })).slice(0, 24);
        recentFile.setText(JSON.stringify(root.recent));
    }
}
