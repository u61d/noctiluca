pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.core

// only one program can own org.freedesktop.Notifications. if mako/dunst/swaync got it first
// we'd silently get nothing, so check the owner and say so. the server takes the name over
// by itself once the other one quits.
Singleton {
    id: root

    readonly property bool dnd: Settings.notifications.dnd
    function setDnd(on: bool): void { Settings.notifications.dnd = on; }

    property var history: []
    property var popups: []

    readonly property int maxHistory: 100
    readonly property int maxPopups: Math.max(1, Settings.notifications.maxToasts)
    readonly property int unread: root.history.filter(function(n) { return !n.seen; }).length

    // "ours", "taken" or "unknown"
    property string busState: "unknown"
    property string busOwner: ""

    property int counter: 0
    function stamp(entry: var): var {
        if (!entry.uid) entry.uid = ++root.counter;
        return entry;
    }

    signal shown(var entry)

    function markAllSeen(): void {
        const h = root.history.slice();
        for (const e of h) e.seen = true;
        root.history = h;
    }

    function clearHistory(): void {
        for (const e of root.history)
            if (e.notification && e.notification.tracked) e.notification.dismiss();
        root.history = [];
        root.popups = [];
    }

    function dismissPopup(entry: var): void {
        root.popups = root.popups.filter(function(p) { return p !== entry; });
    }

    function dismiss(entry: var): void {
        root.dismissPopup(entry);
        root.history = root.history.filter(function(h) { return h !== entry; });
        // lets chat apps stop showing it as unread
        if (entry.notification && entry.notification.tracked) entry.notification.dismiss();
    }

    // ms on screen, 0 = until dismissed. expireTimeout -1 means "server decides"
    function lifetime(n: var): int {
        if (n.urgency === NotificationUrgency.Critical) return 0;
        if (n.expireTimeout > 0) return n.expireTimeout;
        const s = Math.max(2, Settings.notifications.timeout) * 1000;
        return n.urgency === NotificationUrgency.Low ? Math.round(s * 0.7) : s;
    }

    function push(entry: var): void {
        root.stamp(entry);
        root.history = [entry].concat(root.history).slice(0, root.maxHistory);
        if (!root.dnd || entry.urgency === NotificationUrgency.Critical) {
            root.popups = [entry].concat(root.popups).slice(0, root.maxPopups);
            root.shown(entry);
        }
    }

    NotificationServer {
        id: server

        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: function(notification) { root.receive(notification); }
    }

    // keeps the Notification itself so replaced ones (progress, volume osd) update in place
    function receive(notification: var): void {
        notification.tracked = true;
        root.busState = "ours";
        root.push({
            notification: notification,
            id: notification.id,
            appName: notification.appName,
            appIcon: notification.appIcon,
            summary: notification.summary,
            body: notification.body,
            image: notification.image,
            urgency: notification.urgency,
            expireTimeout: notification.expireTimeout,
            actions: notification.actions,
            time: new Date(),
            seen: false
        });
    }

    function imageOf(entry: var): string {
        if (!Settings.notifications.images) return "";
        const n = entry.notification || entry;
        const img = n.image || "";
        if (img === "") return "";
        if (img.startsWith("/")) return "file://" + img;
        return img;
    }

    function appIconOf(entry: var): string {
        const n = entry.notification || entry;
        const de = n.desktopEntry || "";
        if (de !== "") {
            const d = DesktopEntries.byId(de);
            if (d && d.icon) return Quickshell.iconPath(d.icon, true);
        }
        const icon = n.appIcon || "";
        if (icon.startsWith("/")) return "file://" + icon;
        if (icon.indexOf("://") > 0) return icon;
        if (icon !== "") {
            const p = Quickshell.iconPath(icon, true);
            if (p !== "") return p;
        }
        const name = (n.appName || "").trim();
        if (name !== "") {
            const d = DesktopEntries.heuristicLookup(name);
            if (d && d.icon) return Quickshell.iconPath(d.icon, true);
            return Quickshell.iconPath(name.toLowerCase(), true);
        }
        return "";
    }
    // old callers
    function picture(entry: var): string {
        const i = root.imageOf(entry);
        return i !== "" ? i : root.appIconOf(entry);
    }

    // [{ app, items }], newest first
    readonly property var groups: {
        const order = [], by = {};
        const together = Settings.notifications.groupByApp;
        for (const e of root.history) {
            const key = together ? (e.appName || "notification").toLowerCase() : "#" + root.stamp(e).uid;
            if (!(key in by)) { by[key] = { app: e.appName || "notification", items: [] }; order.push(key); }
            by[key].items.push(e);
        }
        return order.map(function(k) { return by[k]; });
    }
    function dismissGroup(app: string): void {
        const key = app.toLowerCase();
        for (const e of root.history.slice())
            if ((e.appName || "notification").toLowerCase() === key) root.dismiss(e);
    }

    function reply(entry: var, text: string): void {
        const n = entry.notification;
        if (!n || !n.hasInlineReply || text.trim() === "") return;
        n.sendInlineReply(text);
        root.dismiss(entry);
    }

    // `test` shows a toast without d-bus, to tell "nothing arrives" from "not drawn"
    IpcHandler {
        target: "notifications"

        function status(): string {
            return JSON.stringify({
                bus: root.busState,
                owner: root.busOwner,
                received: root.history.length,
                showing: root.popups.length,
                dnd: root.dnd
            });
        }

        function test(): void {
            root.push({
                appName: "noctiluca",
                summary: "Test from inside the shell",
                body: "If you see this, drawing works; anything missing is on the D-Bus side.",
                urgency: NotificationUrgency.Normal,
                expireTimeout: 8000,
                actions: [],
                image: "",
                time: new Date(),
                seen: false
            });
        }

        function recheck(): void {
            root.tries = 0;
            whoOwns.running = true;
        }
    }

    property bool warned: false
    property int tries: 0        // busctl missing or silent: give up after a few looks

    Process {
        id: whoOwns
        // $PPID is us, sh is started straight from quickshell
        command: ["sh", "-c", "echo self=$PPID; busctl --user status org.freedesktop.Notifications 2>/dev/null | grep -E '^(PID|Comm|CommandLine)='"]
        stdout: StdioCollector {
            onStreamFinished: root.readOwner(this.text)
        }
    }

    function readOwner(text: string): void {
        const lines = text.split("\n");
        let self = "", pid = "", comm = "", cmd = "";
        for (const l of lines) {
            if (l.startsWith("self=")) self = l.slice(5).trim();
            else if (l.startsWith("PID=")) pid = l.slice(4).trim();
            else if (l.startsWith("Comm=")) comm = l.slice(5).trim();
            else if (l.startsWith("CommandLine=")) cmd = l.slice(12).trim();
        }
        if (pid === "") {
            root.busState = "unknown";
            root.tries++;
            return;
        }
        if (pid === self) {
            root.busState = "ours";
            root.busOwner = "";
            return;
        }
        root.busState = "taken";
        root.busOwner = comm !== "" ? comm : cmd.split(" ")[0];
        if (!root.warned) {
            root.warned = true;
            root.push({
                appName: "noctiluca",
                summary: "Notifications are going to " + root.busOwner,
                body: "Another notification daemon got the bus first, so nothing reaches this shell. "
                      + "Stop it (pkill " + root.busOwner + ") and remove it from autostart; "
                      + "this shell takes over on its own the moment it quits.",
                urgency: NotificationUrgency.Critical,
                expireTimeout: -1,
                actions: [],
                image: "",
                time: new Date(),
                seen: false
            });
        }
    }

    Timer {
        interval: root.busState === "taken" ? 15000 : 2500
        running: root.busState !== "ours" && root.tries < 4
        repeat: true
        triggeredOnStart: false
        onTriggered: whoOwns.running = true
    }
}
