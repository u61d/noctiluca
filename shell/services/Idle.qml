pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core

// hypridle only does lock-before-sleep (it holds the logind delay inhibitor). inhibitors
// are respected, which is how caffeine and music work (Surface.qml)
Singleton {
    id: root

    readonly property bool caffeine: Settings.idle.caffeine
    function setCaffeine(on: bool): void { Settings.idle.caffeine = on; }

    IdleMonitor {
        enabled: Settings.idle.lockMinutes > 0
        timeout: Math.max(1, Settings.idle.lockMinutes) * 60
        respectInhibitors: true
        onIsIdleChanged: if (this.isIdle) Session.lock()
    }

    IdleMonitor {
        enabled: Settings.idle.screenOffMinutes > 0
        timeout: Math.max(1, Settings.idle.screenOffMinutes) * 60
        respectInhibitors: true
        onIsIdleChanged: Quickshell.execDetached(["hyprctl", "dispatch",
                                                  "hl.dsp.dpms({ action = \"" + (this.isIdle ? "off" : "on") + "\" })"])
    }

    IdleMonitor {
        enabled: Settings.idle.suspendMinutes > 0
        timeout: Math.max(1, Settings.idle.suspendMinutes) * 60
        respectInhibitors: true
        onIsIdleChanged: if (this.isIdle) Quickshell.execDetached(["systemctl", "suspend"])
    }
}
