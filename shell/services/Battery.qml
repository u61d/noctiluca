pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.Notifications
import qs.core
import qs.components

Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: root.dev !== null && root.dev.ready && root.dev.isLaptopBattery
    readonly property real level: root.present ? root.dev.percentage : 0          // 0..1
    readonly property int percent: Math.round(root.level * 100)
    readonly property bool charging: root.present
        && (root.dev.state === UPowerDeviceState.Charging || root.dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: root.present && root.dev.state === UPowerDeviceState.FullyCharged
    readonly property bool onAc: !UPower.onBattery

    readonly property string estimate: {
        if (!root.present) return "";
        const s = root.charging ? root.dev.timeToFull : root.dev.timeToEmpty;
        if (!s || s <= 0) return root.full ? "full" : root.charging ? "charging" : "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        const t = (h > 0 ? h + " h " : "") + m + " min";
        return root.charging ? "full in " + t : t + " left";
    }

    readonly property string icon: root.charging || root.full ? Icons.batteryCharging
        : root.level < 0.15 ? Icons.batteryWarning
        : root.level < 0.4 ? Icons.batteryLow
        : root.level < 0.75 ? Icons.batteryMedium : Icons.batteryFull

    // warn once when low, again when nearly out; plugging in resets both
    property int warned: 100
    onPercentChanged: {
        if (!root.present || root.charging || root.onAc) { root.warned = 100; return; }
        const step = root.percent <= 5 ? 5 : root.percent <= 15 ? 15 : 100;
        if (step >= root.warned) return;
        root.warned = step;
        Notifs.push({
            appName: "battery", glyph: root.icon,
            summary: step === 5 ? "Battery almost empty" : "Battery low",
            body: root.percent + "%" + (root.estimate !== "" ? ", " + root.estimate : "") + ". Plug in soon.",
            urgency: step === 5 ? NotificationUrgency.Critical : NotificationUrgency.Normal,
            expireTimeout: -1, actions: [], image: "", time: new Date(), seen: false
        });
    }
    onChargingChanged: if (root.charging) root.warned = 100
}
