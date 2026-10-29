pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// while it's on we keep a hyprsunset running; it restores the colours when it exits.
// temperature changes go over its ipc, no restart
Singleton {
    id: root

    property bool available: false
    readonly property int temperature: Math.max(1500, Math.min(6500, Settings.nightLight.temperature))

    function minutes(hhmm: string): int {
        const m = /^(\d{1,2}):(\d{2})$/.exec(hhmm.trim());
        return m ? (Number(m[1]) % 24) * 60 + Number(m[2]) % 60 : 0;
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: Settings.nightLight.scheduled
    }
    readonly property bool inWindow: {
        const now = clock.date.getHours() * 60 + clock.date.getMinutes();
        const a = root.minutes(Settings.nightLight.from), b = root.minutes(Settings.nightLight.to);
        return a <= b ? (now >= a && now < b) : (now >= a || now < b);    // across midnight
    }
    readonly property bool active: root.available
        && (Settings.nightLight.scheduled ? root.inWindow : Settings.nightLight.enabled)

    // outside a schedule it just flips; inside one it ends the schedule and keeps what you asked for
    function toggle(): void {
        const want = !root.active;
        Settings.nightLight.scheduled = false;
        Settings.nightLight.enabled = want;
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v hyprsunset"]
        onExited: function(code) { root.available = code === 0; }
    }

    Process {
        id: sunset
        command: ["hyprsunset", "-t", String(root.temperature)]
        running: root.active
    }

    onTemperatureChanged: if (sunset.running) retune.restart()
    Timer {
        id: retune
        interval: 120
        onTriggered: Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(root.temperature)])
    }
}
