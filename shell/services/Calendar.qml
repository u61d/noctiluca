pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// a TZID time is taken as local, which is right whenever the calendar is in your zone
Singleton {
    id: root

    readonly property var sources: Settings.calendar.sources || []
    readonly property bool enabled: root.sources.length > 0
    property var events: []              // [{ start, end, allDay, title, location, source }], sorted
    property string error: ""
    property bool loading: fetch.running

    onSourcesChanged: root.refresh()
    Component.onCompleted: root.refresh()
    Timer { interval: 15 * 60 * 1000; repeat: true; running: root.enabled; onTriggered: root.refresh() }
    SystemClock { id: day; precision: SystemClock.Hours }
    property int lastDay: -1
    Connections {
        target: day
        function onDateChanged() {
            if (day.date.getDate() !== root.lastDay) { root.lastDay = day.date.getDate(); root.expandAll(); }
        }
    }

    function refresh(): void {
        if (!root.enabled) { root.events = []; return; }
        if (fetch.running) return;
        fetch.command = ["sh", "-c",
            "i=0; for s in \"$@\"; do printf '\\n@@SOURCE %s\\n' \"$i\";"
            + " case \"$s\" in http*|webcal*) curl -fsSL --max-time 15 \"$(printf %s \"$s\" | sed 's#^webcal#https#')\" || echo '@@FAILED';;"
            + " *) f=$(printf %s \"$s\" | sed \"s#^~#$HOME#\"); cat \"$f\" 2>/dev/null || echo '@@FAILED';; esac; i=$((i+1)); done",
            "sh"].concat(root.sources);
        fetch.running = true;
    }

    property var parsed: []              // raw VEVENTs from the last fetch
    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split(/\n@@SOURCE (\d+)\n/);
                const all = [], failed = [];
                for (let i = 1; i + 1 < parts.length; i += 2) {
                    const src = Number(parts[i]), body = parts[i + 1];
                    if (body.indexOf("@@FAILED") >= 0 && body.indexOf("BEGIN:VCALENDAR") < 0) { failed.push(root.sources[src]); continue; }
                    for (const ev of root.parse(body)) { ev.source = src; all.push(ev); }
                }
                root.error = failed.length > 0 ? "couldn't read " + failed.join(", ") : "";
                root.parsed = all;
                root.expandAll();
            }
        }
    }

    function unfold(text: string): var {
        return text.replace(/\r\n/g, "\n").replace(/\n[ \t]/g, "").split("\n");
    }
    function plain(s: string): string {
        return s.replace(/\\n/gi, " ").replace(/\\([,;\\])/g, "$1").trim();
    }
    // "20261024T153000Z", "20261024T153000", "20261024" -> { date, allDay }
    function when(value: string, params: string): var {
        const m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/.exec(value.trim());
        if (!m) return null;
        const y = Number(m[1]), mo = Number(m[2]) - 1, d = Number(m[3]);
        if (m[4] === undefined || /VALUE=DATE(?!-)/.test(params)) return { date: new Date(y, mo, d), allDay: true };
        const h = Number(m[4]), mi = Number(m[5]), s = Number(m[6] || 0);
        return { date: m[7] ? new Date(Date.UTC(y, mo, d, h, mi, s)) : new Date(y, mo, d, h, mi, s), allDay: false };
    }
    function parse(text: string): var {
        const out = [];
        let cur = null;
        for (const line of root.unfold(text)) {
            if (line === "BEGIN:VEVENT") { cur = { exdates: [] }; continue; }
            if (line === "END:VEVENT") { if (cur && cur.start) out.push(cur); cur = null; continue; }
            if (!cur) continue;
            const colon = line.indexOf(":");
            if (colon < 0) continue;
            const head = line.slice(0, colon), value = line.slice(colon + 1);
            const semi = head.indexOf(";");
            const name = (semi < 0 ? head : head.slice(0, semi)).toUpperCase();
            const params = semi < 0 ? "" : head.slice(semi + 1);
            switch (name) {
            case "SUMMARY": cur.title = root.plain(value); break;
            case "LOCATION": cur.location = root.plain(value); break;
            case "DTSTART": { const w = root.when(value, params); if (w) { cur.start = w.date; cur.allDay = w.allDay; } break; }
            case "DTEND": { const w = root.when(value, params); if (w) cur.end = w.date; break; }
            case "DURATION": cur.duration = value; break;
            case "RRULE": cur.rrule = value; break;
            case "EXDATE":
                for (const v of value.split(",")) { const w = root.when(v, params); if (w) cur.exdates.push(w.date.getTime()); }
                break;
            case "STATUS": if (value.trim().toUpperCase() === "CANCELLED") cur.cancelled = true; break;
            }
        }
        return out.filter(function(e) { return !e.cancelled; });
    }
    // "PT1H30M", "P1D" -> ms
    function duration(d: string): int {
        const m = /^P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec((d || "").trim());
        if (!m) return 0;
        return ((Number(m[1] || 0) * 7 + Number(m[2] || 0)) * 86400 + Number(m[3] || 0) * 3600
                + Number(m[4] || 0) * 60 + Number(m[5] || 0)) * 1000;
    }

    readonly property var dayCodes: ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
    function occurrences(ev: var, from: date, to: date): var {
        const len = ev.end ? ev.end - ev.start : ev.duration ? root.duration(ev.duration) : (ev.allDay ? 86400000 : 0);
        const one = function(s) { return { start: s, end: new Date(s.getTime() + len), allDay: ev.allDay,
                                           title: ev.title || "(no title)", location: ev.location || "", source: ev.source }; };
        if (!ev.rrule) return ev.start < to && new Date(ev.start.getTime() + Math.max(len, 1)) > from ? [one(ev.start)] : [];

        const r = {};
        for (const kv of ev.rrule.split(";")) { const i = kv.indexOf("="); if (i > 0) r[kv.slice(0, i).toUpperCase()] = kv.slice(i + 1); }
        const freq = r.FREQ, step = Math.max(1, Number(r.INTERVAL || 1));
        const count = r.COUNT ? Number(r.COUNT) : Infinity;
        const until = r.UNTIL ? (root.when(r.UNTIL, "") || {}).date : null;
        const byDay = r.BYDAY ? r.BYDAY.split(",").map(function(s) { return root.dayCodes.indexOf(s.slice(-2)); }).filter(function(x) { return x >= 0; }) : [];
        const out = [];
        let n = 0;
        const s0 = ev.start;
        const push = function(s) {
            if (until && s > until) return false;
            if (n >= count) return false;
            n++;
            if (ev.exdates.indexOf(s.getTime()) < 0 && s < to && new Date(s.getTime() + Math.max(len, 1)) > from) out.push(one(s));
            return true;
        };
        for (let i = 0; i < 2000; i++) {
            let base;
            if (freq === "DAILY") base = new Date(s0.getFullYear(), s0.getMonth(), s0.getDate() + i * step, s0.getHours(), s0.getMinutes(), s0.getSeconds());
            else if (freq === "WEEKLY") base = new Date(s0.getFullYear(), s0.getMonth(), s0.getDate() + i * 7 * step, s0.getHours(), s0.getMinutes(), s0.getSeconds());
            else if (freq === "MONTHLY") base = new Date(s0.getFullYear(), s0.getMonth() + i * step, s0.getDate(), s0.getHours(), s0.getMinutes(), s0.getSeconds());
            else if (freq === "YEARLY") base = new Date(s0.getFullYear() + i * step, s0.getMonth(), s0.getDate(), s0.getHours(), s0.getMinutes(), s0.getSeconds());
            else return [one(s0)];
            if (base > to) break;
            if (until && base > until) break;
            if (freq === "WEEKLY" && byDay.length > 0) {
                const monday = new Date(base.getFullYear(), base.getMonth(), base.getDate() - ((base.getDay() + 6) % 7), s0.getHours(), s0.getMinutes(), s0.getSeconds());
                for (const wd of byDay.slice().sort(function(a, b) { return ((a + 6) % 7) - ((b + 6) % 7); })) {
                    const s = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + ((wd + 6) % 7), s0.getHours(), s0.getMinutes(), s0.getSeconds());
                    if (s < s0) continue;
                    if (!push(s)) return out;
                }
            } else {
                // monthly on the 31st skips months without one, like calendars do
                if (freq === "MONTHLY" && base.getDate() !== s0.getDate()) continue;
                if (!push(base)) return out;
            }
        }
        return out;
    }

    function expandAll(): void {
        const now = new Date();
        const from = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const to = new Date(from.getFullYear(), from.getMonth(), from.getDate() + Math.max(1, Settings.calendar.days));
        const wideFrom = new Date(from.getFullYear(), from.getMonth() - 1, 1);
        const wideTo = new Date(from.getFullYear(), from.getMonth() + 3, 1);
        let all = [];
        for (const ev of root.parsed) all = all.concat(root.occurrences(ev, wideFrom, wideTo));
        all.sort(function(a, b) { return a.start - b.start || (b.allDay ? 1 : 0) - (a.allDay ? 1 : 0); });
        root.marked = all.map(function(e) { return root.key(e.start); });
        root.events = all.filter(function(e) { return e.end > now && e.start < to || (e.allDay && e.end > from && e.start < to); });
    }

    property var marked: []
    function key(d: date): string {
        return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
    }
    function has(d: date): bool { return root.marked.indexOf(root.key(d)) >= 0; }

    function dayLabel(d: date): string {
        const t = new Date(); t.setHours(0, 0, 0, 0);
        const x = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        const diff = Math.round((x - t) / 86400000);
        return diff === 0 ? "today" : diff === 1 ? "tomorrow" : Qt.formatDate(d, "ddd d");
    }
}
