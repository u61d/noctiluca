pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.core

// networkmanager only (quickshell's only backend). a Network has `connected`, not `active`
Singleton {
    id: root

    readonly property var devices: Networking.devices ? Networking.devices.values : []

    readonly property var device: {
        let wifi = null;
        for (const d of root.devices) {
            if (!d || !d.connected) continue;
            if (d.type === DeviceType.Wired) return d;
            if (d.type === DeviceType.Wifi && !wifi) wifi = d;
        }
        return wifi;
    }

    readonly property bool online: root.device !== null
    readonly property string kind: !root.device ? "none"
                                  : root.device.type === DeviceType.Wired ? "wired" : "wifi"

    readonly property var network: {
        if (!root.device || root.device.type !== DeviceType.Wifi || !root.device.networks) return null;
        for (const n of root.device.networks.values)
            if (n && n.connected) return n;
        return null;
    }

    readonly property string name: root.network && root.network.name ? root.network.name
                                  : root.kind === "wired" ? "Wired" + (root.device.name ? " (" + root.device.name + ")" : "")
                                  : root.device && root.device.name ? root.device.name : ""

    readonly property real strength: root.kind === "wired" ? 1
                                   : root.network ? root.network.signalStrength : 0

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool hasWifiHardware: {
        for (const d of root.devices)
            if (d && d.type === DeviceType.Wifi) return true;
        return false;
    }

    function setWifi(on: bool): void {
        Networking.wifiEnabled = on;
    }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btPresent: root.adapter !== null
    readonly property bool btEnabled: root.adapter ? root.adapter.enabled : false
    readonly property var btConnected: {
        const out = [];
        const devs = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (const d of devs)
            if (d && d.connected) out.push(d);
        return out;
    }

    function setBluetooth(on: bool): void {
        if (root.adapter) root.adapter.enabled = on;
    }
}
