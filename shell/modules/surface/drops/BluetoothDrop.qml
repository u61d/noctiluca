import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import qs.core
import qs.components
import qs.services

Item {
    id: root

    property var host: null

    implicitWidth: 400
    implicitHeight: col.implicitHeight

    readonly property var adapter: Net.adapter
    readonly property var all: Bluetooth.devices ? Bluetooth.devices.values.filter(function(d) { return d && (d.name || d.deviceName); }) : []
    readonly property var connected: root.all.filter(function(d) { return d.connected; })
    readonly property var mine: root.all.filter(function(d) { return d.paired && !d.connected; })
    readonly property var nearby: root.all.filter(function(d) { return !d.paired && !d.connected; }).slice(0, 7)

    Component.onCompleted: if (root.adapter && root.adapter.enabled) root.adapter.discovering = true
    Component.onDestruction: if (root.adapter) root.adapter.discovering = false

    // trust and connect once pairing finishes, no second click
    property var connectAfterPair: null

    function pick(d: var): void {
        if (d.pairing) {
            d.cancelPair();
        } else if (d.connected) {
            d.disconnect();
        } else if (d.paired) {
            d.connect();
        } else {
            root.connectAfterPair = d;
            d.pair();
        }
    }

    function iconFor(d: var): string {
        const i = (d.icon || "").toLowerCase();
        if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0 || i.indexOf("audio") >= 0) return Icons.headphones;
        if (i.indexOf("keyboard") >= 0) return Icons.keyboard;
        if (i.indexOf("mouse") >= 0 || i.indexOf("input") >= 0) return Icons.cursor;
        if (i.indexOf("speaker") >= 0) return Icons.speaker;
        if (i.indexOf("phone") >= 0) return Icons.app;
        if (i.indexOf("computer") >= 0) return Icons.monitor;
        return Icons.bluetooth;
    }

    component Section: Item {
        id: sec
        property string label: ""
        width: parent ? parent.width : 0
        height: 34
        Text {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            text: sec.label
            font.family: Tokens.fontSans; font.pixelSize: 12; font.weight: Font.Medium
            renderType: Text.NativeRendering
            color: Theme.mute
        }
    }

    component DeviceRow: Item {
        id: dr
        required property var modelData
        property var panel: null
        height: 50

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2; anchors.bottomMargin: 2
            radius: 14
            color: dh.hovered ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
        }
        Rectangle {
            x: 6
            width: 36; height: 36; radius: 18
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            Icon {
                anchors.centerIn: parent
                path: dr.panel ? dr.panel.iconFor(dr.modelData) : ""
                size: 16
                color: dr.modelData.paired ? Theme.dim : Theme.mute
            }
        }
        Text {
            x: 56
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 56 - st.width - 20
            text: dr.modelData.name || dr.modelData.deviceName
            elide: Text.ElideRight
            font.family: Tokens.fontSans; font.pixelSize: 13
            renderType: Text.NativeRendering
            color: dh.hovered ? Theme.text : Theme.dim
        }
        Text {
            id: st
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: dr.modelData.pairing ? "Pairing…"
                : dr.modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                : dr.modelData.paired ? (dh.hovered ? "Connect" : "")
                : dh.hovered ? "Pair" : ""
            font.family: Tokens.fontMono; font.pixelSize: 10
            renderType: Text.NativeRendering
            color: dr.modelData.pairing ? Theme.glow : Theme.mute
        }
        HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: dr.panel.pick(dr.modelData) }

        Connections {
            target: dr.modelData
            function onPairedChanged() {
                if (dr.modelData.paired && dr.panel.connectAfterPair === dr.modelData) {
                    dr.panel.connectAfterPair = null;
                    dr.modelData.trusted = true;
                    dr.modelData.connect();
                }
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 0

        PanelHead {
            width: parent.width
            icon: Net.btEnabled ? Icons.bluetoothOn : Icons.bluetoothOff
            title: "Bluetooth"
            note: !root.adapter ? "No adapter"
                : !Net.btEnabled ? "Off"
                : root.connected.length === 1 ? (root.connected[0].name || root.connected[0].deviceName)
                : root.connected.length > 1 ? root.connected.length + " devices connected"
                : root.adapter.discovering ? "Looking for devices…" : "On"
            on: Net.btEnabled
            busy: root.adapter !== null && root.adapter.discovering
            hasSwitch: root.adapter !== null
            onToggled: function(on) {
                Net.setBluetooth(on);
                if (on && root.adapter) root.adapter.discovering = true;
            }
        }
        Item { width: 1; height: 18 }

        Repeater {
            model: Net.btEnabled ? root.connected : []
            delegate: Item {
                id: card
                required property var modelData
                width: col.width
                height: 80
                readonly property bool hasBattery: !!card.modelData.batteryAvailable
                readonly property real level: card.hasBattery ? card.modelData.battery : 0

                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: 8
                    radius: 18
                    color: Qt.rgba(1, 1, 1, 0.05)
                }
                Item {
                    id: ring
                    x: 14
                    width: 46; height: 46
                    y: (card.height - 8 - height) / 2
                                        Icon { anchors.centerIn: parent; path: root.iconFor(card.modelData); size: 18; color: Theme.glowHi }
                    Shape {
                        anchors.fill: parent
                        visible: card.hasBattery
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Qt.rgba(1, 1, 1, 0.1); strokeWidth: 2; fillColor: "transparent"
                            PathAngleArc { centerX: 23; centerY: 23; radiusX: 22; radiusY: 22; startAngle: 0; sweepAngle: 360 }
                        }
                        ShapePath {
                            strokeColor: card.level <= 0.15 ? Theme.alert : Theme.glow
                            strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                            PathAngleArc { centerX: 23; centerY: 23; radiusX: 22; radiusY: 22; startAngle: -90; sweepAngle: 360 * card.level }
                        }
                    }
                }
                Column {
                    anchors { left: ring.right; leftMargin: 14; right: dis.left; rightMargin: 10; verticalCenter: ring.verticalCenter }
                    spacing: 3
                    Text {
                        width: parent.width
                        text: card.modelData.name || card.modelData.deviceName
                        elide: Text.ElideRight
                        font.family: Tokens.fontSans; font.pixelSize: 15; font.weight: Font.Medium
                        renderType: Text.NativeRendering
                        color: Theme.text
                    }
                    Text {
                        text: card.hasBattery ? Math.round(card.level * 100) + "% battery" : "Connected"
                        font.family: Tokens.fontSans; font.pixelSize: 12
                        renderType: Text.NativeRendering
                        color: Theme.dim
                    }
                }
                Item {
                    id: dis
                    width: disText.implicitWidth + 28; height: 32
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: ring.verticalCenter }
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: xh.hovered ? Qt.alpha(Theme.alert, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                    }
                    Text {
                        id: disText
                        anchors.centerIn: parent
                        text: "Disconnect"
                        font.family: Tokens.fontSans; font.pixelSize: 12
                        renderType: Text.NativeRendering
                        color: xh.hovered ? Theme.alert : Theme.dim
                    }
                    HoverHandler { id: xh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: card.modelData.disconnect() }
                }
            }
        }

        Section { visible: Net.btEnabled && root.mine.length > 0; label: "Your devices" }
        Repeater {
            model: Net.btEnabled ? root.mine : []
            delegate: DeviceRow { panel: root; width: col.width }
        }

        Section { visible: Net.btEnabled; label: "Nearby" }
        Row {
            visible: Net.btEnabled && root.nearby.length === 0
            bottomPadding: 10
            spacing: 10
            Node {
                anchors.verticalCenter: parent.verticalCenter
                core: 4; halo: 4
                color: Theme.glow
                breathing: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Looking… put your device in pairing mode."
                font.family: Tokens.fontSans; font.pixelSize: 12
                renderType: Text.NativeRendering
                color: Theme.mute
            }
        }
        Repeater {
            model: Net.btEnabled ? root.nearby : []
            delegate: DeviceRow { panel: root; width: col.width }
        }
    }
}
