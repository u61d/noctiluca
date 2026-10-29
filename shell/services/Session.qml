pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// lock() only asks, Lock.qml owns the lock
Singleton {
    id: root

    property bool lockRequested: false
    readonly property string username: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""

    function lock() { root.lockRequested = true; }

    property bool wantUptime: false
    property string uptime: ""

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        // no watchChanges, /proc/uptime changes constantly
        onLoaded: {
            const secs = parseFloat(this.text().split(" ")[0]);
            if (!isFinite(secs)) {
                root.uptime = "";
                return;
            }
            const d = Math.floor(secs / 86400);
            const h = Math.floor(secs % 86400 / 3600);
            const m = Math.floor(secs % 3600 / 60);
            root.uptime = d > 0 ? "up " + d + "d " + h + "h"
                        : h > 0 ? "up " + h + "h " + m + "m"
                                : "up " + m + "m";
        }
        onLoadFailed: root.uptime = ""
    }

    Timer {
        running: root.wantUptime
        interval: 60000
        repeat: true
        triggeredOnStart: true
        onTriggered: uptimeFile.reload()
    }

    // one function per action, never a command built from a label
    function logout() {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]);
    }
    function suspend() { Quickshell.execDetached(["systemctl", "suspend"]); }
    function hibernate() { Quickshell.execDetached(["systemctl", "hibernate"]); }
    function reboot() { Quickshell.execDetached(["systemctl", "reboot"]); }
    function shutdown() { Quickshell.execDetached(["systemctl", "poweroff"]); }

    // logind's Lock signal (loginctl lock-session, which hypridle sends before sleep)
    Process {
        id: monitor
        command: ["dbus-monitor", "--system",
                  "type='signal',interface='org.freedesktop.login1.Session',member='Lock'"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (line.indexOf("member=Lock") >= 0) root.lock();
            }
        }

        onExited: function(code, status) {
            if (code !== 0)
                console.warn("noctiluca: dbus-monitor exited (" + code + "); "
                           + "`loginctl lock-session` will not trigger the lockscreen");
        }
    }
}
