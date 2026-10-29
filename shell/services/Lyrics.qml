pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.services

// lrclib's exact lookup wants title, artist, album and length to match, and players are
// sloppy about all four. so: exact without the album, then a search on a cleaned title,
// closest length wins. cached for the session.
Singleton {
    id: root

    readonly property string api: "https://lrclib.net/api/"

    // see Cava.qml for why names and not a flag
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

    // [{ t: seconds, text: "..." }], sorted
    property var lines: []
    property string plain: ""
    property bool instrumental: false
    property string state: "idle"        // idle | loading | ok | none | error
    property string lastKey: ""

    readonly property bool synced: root.lines.length > 0

    readonly property int index: {
        if (!root.synced) return -1;
        const t = Players.position + 0.15;     // a bit early reads better than late
        let lo = 0, hi = root.lines.length - 1, found = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (root.lines[mid].t <= t) { found = mid; lo = mid + 1; } else hi = mid - 1;
        }
        return found;
    }

    readonly property string currentLine: root.index >= 0 && root.index < root.lines.length
        ? root.lines[root.index].text : ""
    readonly property string nextLine: root.index + 1 < root.lines.length
        ? root.lines[root.index + 1].text : ""

    function clear(): void {
        root.lines = [];
        root.plain = "";
        root.instrumental = false;
    }

    function parseLrc(text: string): var {
        const out = [];
        for (const raw of text.split("\n")) {
            // a line can have several stamps: [00:12.34][01:02.00] words
            const stamps = raw.match(/\[(\d+):(\d+(?:\.\d+)?)\]/g);
            if (!stamps) continue;
            const words = raw.replace(/\[(\d+):(\d+(?:\.\d+)?)\]/g, "").trim();
            for (const s of stamps) {
                const m = s.match(/\[(\d+):(\d+(?:\.\d+)?)\]/);
                if (!m) continue;
                out.push({ t: parseInt(m[1], 10) * 60 + parseFloat(m[2]), text: words });
            }
        }
        out.sort(function(a, b) { return a.t - b.t; });
        return out;
    }

    // "Song (feat. X) - Remastered 2011 [Official Video]" -> "Song"
    function cleanTitle(title: string): string {
        let t = title;
        t = t.replace(/\s*[\(\[][^\)\]]*(feat\.?|ft\.?|with |official|video|audio|lyrics?|visuali[sz]er|remaster|live|version|edit|mix|explicit|hd|hq|4k)[^\)\]]*[\)\]]/gi, "");
        t = t.replace(/\s+-\s+.*(remaster|version|edit|mix|live|mono|stereo|single|radio|demo).*$/i, "");
        t = t.replace(/\s+(feat\.?|ft\.?)\s+.*$/i, "");
        return t.trim();
    }
    // "A, B & C" -> "A"
    function firstArtist(artist: string): string {
        return artist.split(/\s*(?:,|&|;| x | feat\.? | ft\.? | and )\s*/i)[0].trim();
    }
    // browsers often give no artist and a title like "Artist - Song"
    function guess(title: string, artist: string): var {
        if (artist !== "" || title.indexOf(" - ") < 0) return { title: title, artist: artist };
        const i = title.indexOf(" - ");
        return { title: title.slice(i + 3), artist: title.slice(0, i) };
    }

    function plan(title: string, artist: string, length: real): var {
        const g = root.guess(title, artist);
        if (g.title === "" || g.artist === "") return [];
        const dur = length > 0 ? "&duration=" + Math.round(length) : "";
        const enc = encodeURIComponent;
        const clean = root.cleanTitle(g.title), first = root.firstArtist(g.artist);
        const steps = [
            "get?track_name=" + enc(g.title) + "&artist_name=" + enc(g.artist) + dur,
            "search?track_name=" + enc(clean) + "&artist_name=" + enc(first),
        ];
        if (clean !== g.title || first !== g.artist)
            steps.splice(1, 0, "get?track_name=" + enc(clean) + "&artist_name=" + enc(first) + dur);
        steps.push("search?q=" + enc(first + " " + clean));
        return steps;
    }

    // closest length with lyrics, within 10s if we know the length
    function pick(results: var, length: real): var {
        if (!Array.isArray(results)) return results && (results.syncedLyrics || results.plainLyrics || results.instrumental) ? results : null;
        let best = null, bestScore = 1e9;
        for (const r of results) {
            if (!r || !(r.syncedLyrics || r.plainLyrics || r.instrumental)) continue;
            const off = length > 0 && r.duration ? Math.abs(r.duration - length) : 0;
            if (length > 0 && r.duration && off > 10) continue;
            const score = off + (r.syncedLyrics ? 0 : 30);
            if (score < bestScore) { best = r; bestScore = score; }
        }
        return best;
    }

    function use(doc: var): void {
        root.instrumental = doc.instrumental === true;
        if (doc.syncedLyrics) root.lines = root.parseLrc(doc.syncedLyrics);
        if (doc.plainLyrics) root.plain = doc.plainLyrics;
        root.state = root.lines.length > 0 || root.plain !== "" || root.instrumental ? "ok" : "none";
    }

    property bool stale: false
    property bool answered: false
    property var cache: ({})
    property var steps: []
    property real askedLength: 0

    function fetch(): void {
        if (!Settings.player.lyrics || !root.wanted) return;
        // one request at a time, a stale answer is thrown away
        if (proc.running) { root.stale = true; return; }
        const key = Players.trackKey;
        root.clear();
        root.lastKey = key;

        if (key in root.cache) {
            const hit = root.cache[key];
            if (hit) root.use(hit); else root.state = "none";
            return;
        }
        root.steps = root.plan(Players.title, Players.artist, Players.length);
        root.askedLength = Players.length;
        if (root.steps.length === 0) { root.state = "none"; return; }
        root.state = "loading";
        root.nextStep();
    }

    function nextStep(): void {
        if (root.steps.length === 0) {
            root.cache[root.lastKey] = null;
            if (root.state === "loading") root.state = "none";
            return;
        }
        const s = root.steps[0];
        root.steps = root.steps.slice(1);
        proc.command = ["curl", "-sS", "--max-time", "8", "-w", "\n%{http_code}",
                        "-H", "User-Agent: NOCTILUCA (a Hyprland desktop; lyrics in its music panel)",
                        root.api + s];
        root.answered = false;
        proc.running = true;
    }

    function answer(text: string): void {
        const cut = text.lastIndexOf("\n");
        const code = parseInt(text.slice(cut + 1), 10);
        const body = text.slice(0, cut);
        if (code === 404 || code === 400) { root.nextStep(); return; }
        if (code !== 200) {
            // network down: say so, but don't cache it as "no lyrics"
            root.steps = [];
            root.state = "error";
            return;
        }
        let doc = null;
        try { doc = root.pick(JSON.parse(body), root.askedLength); } catch (e) { doc = null; }
        if (!doc) { root.nextStep(); return; }
        root.cache[root.lastKey] = doc;
        root.steps = [];
        root.use(doc);
    }

    Connections {
        target: Players
        function onTrackKeyChanged() { if (root.wanted) lookupSoon.restart(); }
    }
    onWantedChanged: if (root.wanted && Players.trackKey !== root.lastKey) lookupSoon.restart()

    // players send title, artist and length one by one, let them settle
    Timer { id: lookupSoon; interval: 400; onTriggered: root.fetch() }

    Process {
        id: proc
        running: false
        // arrives before the process counts as stopped
        stdout: StdioCollector {
            onStreamFinished: {
                root.answered = true;
                if (root.stale || root.lastKey !== Players.trackKey) {
                    root.stale = false;
                    root.fetch();
                    return;
                }
                root.answer(this.text);
            }
        }
        // stopped without answering: no curl
        onRunningChanged: {
            if (!proc.running && !root.answered && root.state === "loading") {
                root.steps = [];
                root.state = "error";
            }
        }
    }
}
