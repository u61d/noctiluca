import QtQuick
import Quickshell
import Quickshell.Networking
import qs.core
import qs.components
import qs.services

Item {
    id: root

    property var host: null

    implicitWidth: 400
    implicitHeight: col.implicitHeight

    readonly property var wifi: {
        for (const d of Net.devices)
            if (d && d.type === DeviceType.Wifi) return d;
        return null;
    }
    readonly property var wired: Net.devices.filter(function(d) { return d && d.type === DeviceType.Wired; })

    readonly property var all: {
        if (!root.wifi || !root.wifi.networks) return [];
        return root.wifi.networks.values.filter(function(n) { return n && n.name; });
    }
    readonly property var current: root.all.find(function(n) { return n.connected; }) || null
    readonly property var others: {
        const list = root.all.filter(function(n) { return !n.connected; });
        list.sort(function(a, b) {
            if (a.known !== b.known) return a.known ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
        return list.slice(0, 8);
    }

    property string asking: ""            // the network whose password field is open
    property string failure: ""

    Component.onCompleted: if (root.wifi) root.wifi.scannerEnabled = true
    Component.onDestruction: if (root.wifi) root.wifi.scannerEnabled = false

    function needsKey(n: var): bool {
        const s = n.security;
        return s === WifiSecurityType.WpaPsk || s === WifiSecurityType.Wpa2Psk || s === WifiSecurityType.Sae;
    }
    function quality(s: real): string {
        return s > 0.75 ? "strong signal" : s > 0.5 ? "good signal" : s > 0.25 ? "weak signal" : "barely there";
    }

    function pick(n: var): void {
        root.failure = "";
        if (n.connected) {
            n.disconnect();
        } else if (n.known || !root.needsKey(n)) {
            n.connect();
        } else {
            root.asking = root.asking === n.name ? "" : n.name;
        }
    }

    component Bars: Row {
        id: bars
        property real strength: 0
        property color lit: Theme.glow
        property real scaleBy: 1
        spacing: 2 * bars.scaleBy
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                width: 3 * bars.scaleBy
                height: (4 + index * 3) * bars.scaleBy
                anchors.bottom: parent ? parent.bottom : undefined
                radius: 1
                color: bars.strength > index * 0.25 ? bars.lit : Qt.rgba(1, 1, 1, 0.12)
            }
        }
    }

    component Section: Item {
        id: sec
        property string label: ""
        property string count: ""
        width: parent ? parent.width : 0
        height: 34
        Text {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            text: sec.label
            font.family: Tokens.fontSans; font.pixelSize: 12; font.weight: Font.Medium
            renderType: Text.NativeRendering
            color: Theme.mute
        }
        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            text: sec.count
            font.family: Tokens.fontMono; font.pixelSize: 10
            renderType: Text.NativeRendering
            color: Theme.mute
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 0

        PanelHead {
            width: parent.width
            icon: !root.wifi || !Net.wifiEnabled ? Icons.wifiOff : Icons.wifi
            title: "Wi-Fi"
            note: !root.wifi ? "No Wi-Fi adapter"
                : !Net.wifiEnabled ? "Off"
                : root.current ? root.current.name
                : root.all.length === 0 ? "Looking for networks…" : root.all.length + " networks nearby"
            on: root.wifi !== null && Net.wifiEnabled
            busy: root.wifi !== null && root.wifi.scannerEnabled && root.all.length === 0
            hasSwitch: root.wifi !== null
            onToggled: function(on) { Net.setWifi(on); }
        }
        Item { width: 1; height: 18 }

        Item {
            visible: Net.wifiEnabled && root.current !== null
            width: parent.width
            height: visible ? 72 : 0

            Rectangle {
                anchors.fill: parent
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.05)
            }
            Bars {
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                strength: root.current ? root.current.signalStrength : 0
                lit: Theme.glow
                scaleBy: 1.35
            }
            Column {
                anchors { left: parent.left; leftMargin: 56; right: disc.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 3
                Text {
                    width: parent.width
                    text: root.current ? root.current.name : ""
                    elide: Text.ElideRight
                    font.family: Tokens.fontSans; font.pixelSize: 15; font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    color: Theme.text
                }
                Text {
                    text: root.current ? "Connected, " + root.quality(root.current.signalStrength) : ""
                    font.family: Tokens.fontSans; font.pixelSize: 12
                    renderType: Text.NativeRendering
                    color: Theme.dim
                }
            }
            Item {
                id: disc
                width: discText.implicitWidth + 28; height: 32
                anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: dch.hovered ? Qt.alpha(Theme.alert, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                }
                Text {
                    id: discText
                    anchors.centerIn: parent
                    text: "Disconnect"
                    font.family: Tokens.fontSans; font.pixelSize: 12
                    renderType: Text.NativeRendering
                    color: dch.hovered ? Theme.alert : Theme.dim
                }
                HoverHandler { id: dch; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: if (root.current) root.current.disconnect() }
            }
        }

        Section {
            visible: Net.wifiEnabled && root.wifi !== null
            label: root.current ? "Other networks" : "Networks"
            count: root.others.length > 0 ? "" + root.others.length : ""
        }
        Text {
            visible: root.wifi !== null && Net.wifiEnabled && root.others.length === 0
            width: parent.width
            bottomPadding: 12
            text: root.all.length === 0 ? "Looking for networks…" : "Nothing else in range."
            font.family: Tokens.fontSans; font.pixelSize: 12
            renderType: Text.NativeRendering
            color: Theme.mute
        }

        Repeater {
            model: Net.wifiEnabled ? root.others : []

            delegate: Column {
                id: row
                required property var modelData
                required property int index
                readonly property bool open: root.asking === row.modelData.name
                width: col.width
                spacing: 0

                Item {
                    width: parent.width
                    height: 50

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 2; anchors.bottomMargin: 2
                        radius: 14
                        color: row.open ? Qt.rgba(1, 1, 1, 0.05) : rh.hovered ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                    }
                    Rectangle {
                        x: 6
                        width: 36; height: 36; radius: 18
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"
                        Bars {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1
                            strength: row.modelData.signalStrength
                            lit: row.modelData.known ? Theme.glow : Theme.dim
                        }
                    }
                    Text {
                        x: 56
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 56 - tail.width - 16
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.family: Tokens.fontSans; font.pixelSize: 13
                        renderType: Text.NativeRendering
                        color: rh.hovered || row.open ? Theme.text : Theme.dim
                    }
                    Row {
                        id: tail
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.stateChanging ? "Connecting…" : row.modelData.known ? "Saved" : rh.hovered ? "Connect" : ""
                            font.family: Tokens.fontMono; font.pixelSize: 10
                            renderType: Text.NativeRendering
                            color: row.modelData.stateChanging ? Theme.glow : Theme.mute
                        }
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.needsKey(row.modelData) && !row.modelData.known
                            path: Icons.lock; size: 13
                            color: Theme.mute
                        }
                    }

                    HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.pick(row.modelData) }
                }

                Item {
                    width: parent.width
                    height: row.open ? 58 : 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }

                    Field {
                        id: psk
                        x: 56
                        y: 8
                        width: parent.width - 56 - go.width - 22
                        placeholder: "password"
                        input.echoMode: TextInput.Password
                        input.passwordCharacter: "•"
                        input.font.pixelSize: 13
                        onAccepted: go.join()
                        onCancelled: root.asking = ""
                    }
                    Item {
                        id: go
                        width: 84; height: 34
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: psk.verticalCenter }
                        function join(): void {
                            if (psk.text === "") return;
                            row.modelData.connectWithPsk(psk.text);
                            psk.text = "";
                            root.asking = "";
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Qt.alpha(Theme.glow, gh.hovered ? 0.28 : 0.18)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "Connect"
                            font.family: Tokens.fontSans; font.pixelSize: 12; font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            color: Theme.glowHi
                        }
                        HoverHandler { id: gh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: go.join() }
                    }
                    onHeightChanged: if (row.open && height > 40) psk.input.forceActiveFocus()
                }

                Connections {
                    target: row.modelData
                    function onConnectionFailed(reason) {
                        root.failure = reason === ConnectionFailReason.NoSecrets
                            ? "Wrong password for " + row.modelData.name
                            : "Couldn't connect to " + row.modelData.name;
                        if (reason === ConnectionFailReason.NoSecrets) root.asking = row.modelData.name;
                    }
                }
            }
        }

        Row {
            visible: root.failure !== ""
            topPadding: 8
            spacing: 8
            Icon { anchors.verticalCenter: parent.verticalCenter; path: Icons.alert; size: 14; color: Theme.alert }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.failure
                font.family: Tokens.fontSans; font.pixelSize: 12
                renderType: Text.NativeRendering
                color: Theme.alert
            }
        }

        Section { visible: root.wired.length > 0; label: "Wired" }
        Repeater {
            model: root.wired
            delegate: Item {
                id: w
                required property var modelData
                width: col.width
                height: 56
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: Qt.rgba(1, 1, 1, 0.035)
                }
                Rectangle {
                    x: 10
                    width: 36; height: 36; radius: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: "transparent"
                    Icon { anchors.centerIn: parent; path: Icons.wired; size: 16; color: w.modelData.connected ? Theme.glow : Theme.mute }
                }
                Column {
                    x: 60
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: w.modelData.name
                        font.family: Tokens.fontSans; font.pixelSize: 13; font.weight: Font.Medium
                        renderType: Text.NativeRendering
                        color: w.modelData.connected ? Theme.text : Theme.dim
                    }
                    Text {
                        text: w.modelData.connected ? (w.modelData.address || "Connected") : "Unplugged"
                        font.family: Tokens.fontMono; font.pixelSize: 10
                        renderType: Text.NativeRendering
                        color: w.modelData.connected ? Theme.glow : Theme.mute
                    }
                }
            }
        }
    }
}
