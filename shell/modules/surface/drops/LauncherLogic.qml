import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core
import qs.components
import qs.services

// split from the view so search and the calculator can be tested alone.
// result: { kind, title, subtitle, glyph, icon, iconName, image, swatch, emoji, payload }
QtObject {
    id: logic

    property string query: ""
    property string openMode: "apps"
    property int selected: 0
    readonly property int maxResults: 8

    signal requestClose()
    signal requestClear()

    readonly property var prefixes: ({ "=": "calc", ">": "run", ":": "clipboard", "/": "files", ";": "emoji", "#": "colors" })
    readonly property string mode: logic.prefixes[logic.query.charAt(0)] || "apps"
    readonly property string term: logic.mode === "apps" ? logic.query : logic.query.slice(1)
    readonly property bool grid: logic.mode === "emoji"
    readonly property int columns: 9

    readonly property string placeholder: {
        switch (logic.mode) {
        case "calc": return "a sum, or 10 km to mi";
        case "run": return "a command to run";
        case "clipboard": return "search the clipboard";
        case "files": return "a file or folder in your home";
        case "emoji": return "describe it: heart, fire, cat";
        case "colors": return "pick a colour, or one from before";
        default: return "Search, or start with = / ; # : >";
        }
    }

    readonly property string emptyText: {
        switch (logic.mode) {
        case "calc": return logic.term === "" ? "" : "not a sum or a conversion";
        case "run": return logic.term === "" ? "type a command" : "";
        case "clipboard": return Clipboard.loading ? "reading clipboard…"
                               : Clipboard.error !== "" ? Clipboard.error
                               : "nothing in the clipboard";
        case "files": return logic.term.trim().length < 2 ? "type a little more" : Files.busy ? "looking…" : "nothing by that name";
        case "emoji": return Emoji.ready ? "no emoji like that" : "loading emoji…";
        default: return logic.term === "" ? "" : "nothing matches";
        }
    }

    onTermChanged: if (logic.mode === "files") Files.search(logic.term)
    onModeChanged: {
        if (logic.mode === "files") Files.search(logic.term);
        if (logic.mode === "clipboard") Clipboard.refresh();
    }

    readonly property var results: {
        switch (logic.mode) {
        case "calc": return logic.calcResults(true);
        case "run": return logic.runResults();
        case "clipboard": return logic.clipResults();
        case "files": return logic.fileResults();
        case "emoji": return logic.emojiResults();
        case "colors": return logic.colorResults();
        default: return logic.appResults();
        }
    }

    onResultsChanged: logic.selected = 0

    function calcResults(explicit: bool): var {
        const conv = Search.convert(logic.term);
        if (conv) {
            const text = Search.formatNumber(Number(conv.result.toPrecision(10)));
            return [{
                kind: "calc", title: text + " " + Search.formatUnit(conv.to),
                subtitle: Search.formatNumber(conv.value) + " " + Search.formatUnit(conv.from),
                glyph: "", icon: Icons.ruler, payload: text
            }];
        }
        // only with an operator, so "2" stays an app search
        if (!explicit && !/[-+*\/^%(]/.test(logic.term)) return [];
        const v = Search.evaluate(logic.term);
        if (v === null) return [];
        return [{
            kind: "calc", title: Search.formatNumber(v),
            subtitle: logic.term,
            glyph: explicit ? "=" : "", icon: explicit ? "" : Icons.calculator, payload: Search.formatNumber(v)
        }];
    }

    function runResults(): var {
        if (logic.term.trim() === "") return [];
        return [{ kind: "run", title: logic.term, subtitle: "run in a shell", icon: Icons.terminal, payload: logic.term }];
    }

    function clipResults(): var {
        const out = [];
        const tick = Clipboard.decoded;          // re-read when pictures land
        for (const e of Clipboard.entries) {
            const info = e.info || null;
            const label = info ? "Picture " + info.w + " × " + info.h : e.preview;
            if (logic.term !== "" && Search.score(logic.term, label) <= 0) continue;
            out.push({
                kind: "clip",
                title: info ? "Picture" : e.preview,
                subtitle: info ? info.w + " × " + info.h + ", " + info.ext + ", " + info.size : "",
                icon: info ? "" : Icons.clipboard,
                image: info && tick >= 0 ? e.image : "",
                payload: e.id
            });
            if (out.length >= logic.maxResults) break;
        }
        return out;
    }

    function fileResults(): var {
        if (logic.term.trim().length < 2) return [];
        return Files.results.slice(0, logic.maxResults).map(function(f) {
            const ext = f.name.indexOf(".") > 0 ? f.name.slice(f.name.lastIndexOf(".") + 1).toLowerCase() : "";
            const picture = ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg"].indexOf(ext) >= 0;
            return {
                kind: "file", title: f.name, subtitle: f.dir,
                icon: f.folder ? Icons.folder : picture ? "" : Icons.file,
                image: picture ? Paths.fileUrl(f.path) : "",
                payload: f.path
            };
        });
    }

    function emojiResults(): var {
        return Emoji.search(logic.term, logic.columns * 4).map(function(r) {
            return { kind: "emoji", title: r[1], emoji: r[0], payload: r[0] };
        });
    }

    function colorResults(): var {
        const out = [{ kind: "pick", title: "Pick a colour from the screen", subtitle: "Super+Shift+C does the same",
                       icon: Icons.colorPicker, payload: "" }];
        const typed = /^#?([0-9a-f]{6}|[0-9a-f]{3})$/i.exec(logic.term.trim());
        let list = Picker.recent.slice();
        if (typed) {
            let h = typed[1].toLowerCase();
            if (h.length === 3) h = h.split("").map(function(c) { return c + c; }).join("");
            list = ["#" + h].concat(list.filter(function(c) { return c !== "#" + h; }));
        }
        for (const c of list) {
            const f = Picker.forms(c);
            out.push({ kind: "color", title: c, subtitle: f[1] + "   " + f[2], swatch: c, payload: c });
            if (out.length >= logic.maxResults) break;
        }
        return out;
    }

    function appResults(): var {
        const apps = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        const visible = apps.filter(function(a) { return a && !a.noDisplay; });

        if (logic.term.trim() === "") {
            const byId = {};
            for (const a of visible) byId[a.id] = a;
            const out = [];
            for (const id of Recents.ids) {
                if (byId[id]) out.push(logic.appEntry(byId[id], "recent"));
                if (out.length >= logic.maxResults) return out;
            }
            const rest = visible.filter(function(a) { return Recents.ids.indexOf(a.id) < 0; })
                                .sort(function(x, y) { return x.name.toLowerCase().localeCompare(y.name.toLowerCase()); });
            for (const a of rest) {
                out.push(logic.appEntry(a, ""));
                if (out.length >= logic.maxResults) break;
            }
            return out;
        }

        const scored = [];
        for (const a of visible) {
            let best = Search.score(logic.term, a.name);
            if (a.genericName) best = Math.max(best, Search.score(logic.term, a.genericName) * 0.6);
            for (const k of (a.keywords || []))
                best = Math.max(best, Search.score(logic.term, k) * 0.5);
            if (best <= 0) continue;
            // small nudge for things you use, never enough to beat a better match
            const r = Recents.ids.indexOf(a.id);
            if (r >= 0) best += 0.04 * (Recents.ids.length - r) / Recents.ids.length;
            scored.push({ item: logic.appEntry(a, ""), s: best });
        }

        if (Settings.launcher.windows) {
            for (const t of (Hyprland.toplevels ? Hyprland.toplevels.values : [])) {
                if (!t || !t.title) continue;
                const app = (t.wayland && t.wayland.appId) || ((t.lastIpcObject || {})["class"]) || "";
                const s = Math.max(Search.score(logic.term, t.title), Search.score(logic.term, app) * 0.8) * 0.85;
                if (s <= 0) continue;
                scored.push({ s: s, item: {
                    kind: "window", title: t.title,
                    subtitle: (app ? app + ", " : "") + "workspace " + (t.workspace ? t.workspace.id : "?"),
                    iconName: app.toLowerCase(), icon: Icons.windows, payload: t
                } });
            }
        }

        if (Settings.launcher.settings) {
            for (const e of SettingsIndex.entries) {
                let s = Search.score(logic.term, e.label);
                for (const w of e.words.split(" ")) s = Math.max(s, Search.score(logic.term, w) * 0.7);
                if (s < 300) continue;                      // only real hits, not scattered letters
                scored.push({ s: s * 0.7, item: { kind: "setting", title: e.label, subtitle: "settings",
                                                   icon: Icons.settings, payload: e.page } });
            }
        }

        scored.sort(function(x, y) { return y.s - x.s; });
        const out = logic.calcResults(false).concat(scored.map(function(e) { return e.item; }));
        return out.slice(0, logic.maxResults);
    }

    function appEntry(a, note: string): var {
        return {
            kind: "app",
            title: a.name,
            subtitle: note !== "" ? note : (a.genericName || a.comment || ""),
            iconName: a.icon || "",
            payload: a
        };
    }

    function move(delta: int) {
        const n = logic.results.length;
        if (n === 0) return;
        logic.selected = (logic.selected + delta % n + n) % n;
    }
    function moveRow(delta: int) {
        if (!logic.grid) { logic.move(delta); return; }
        const n = logic.results.length;
        const next = logic.selected + delta * logic.columns;
        if (next >= 0 && next < n) logic.selected = next;
    }

    function activate(index: int) {
        const r = logic.results[index];
        if (!r) return;
        switch (r.kind) {
        case "app":
            Recents.note(r.payload.id);
            r.payload.execute();
            break;
        case "window":
            Hypr.dispatch("hl.dsp.focus({ window = " + Hypr.luaStr("address:0x" + r.payload.address) + " })");
            break;
        case "setting":
            Panels.openSettings(r.payload);
            break;
        case "run":
            Quickshell.execDetached(["sh", "-c", r.payload]);
            break;
        case "calc":
            Quickshell.execDetached(["wl-copy", r.payload]);
            break;
        case "clip":
            Clipboard.copy(r.payload);
            break;
        case "file":
            Files.open(r.payload);
            break;
        case "emoji":
            Emoji.use(r.payload);
            break;
        case "pick":
            Picker.pick();
            break;
        case "color":
            Picker.copy(r.payload);
            break;
        }
        logic.requestClear();
        logic.requestClose();
    }
}
