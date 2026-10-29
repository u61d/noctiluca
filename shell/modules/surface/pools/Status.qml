import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray as Sni
import qs.core
import qs.components
import qs.services

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 32

    component Glyph: Item {
        id: g
        property string path: ""
        property bool lit: false
        property bool faint: false
        // inline components can't see the file's ids
        property bool hot: false
        width: 16
        height: 16
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Icon {
            anchors.centerIn: parent
            path: g.path
            size: 16
            color: g.lit ? Theme.glow
                 : g.faint ? Qt.alpha(Theme.mute, 0.6)
                 : g.hot ? Theme.text : Theme.dim
            Behavior on color {
                ColorAnimation { duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
            }
        }
    }

    Row {
        id: row
        height: parent.height
        spacing: 18

        Item {
            visible: Recorder.recording
            width: recRow.implicitWidth
            height: parent.height
            Row {
                id: recRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 4
                    color: Theme.alert
                    SequentialAnimation on opacity {
                        running: Recorder.recording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Recorder.clock
                    font.family: Tokens.fontMono; font.pixelSize: 11
                    renderType: Text.NativeRendering
                    color: recHover.hovered ? Theme.text : Theme.alert
                }
            }
            HoverHandler { id: recHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Recorder.stop() }
        }

        Row {
            id: tray
            visible: Settings.bar.tray && trayRepeater.count > 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Repeater {
                id: trayRepeater
                model: Settings.bar.tray ? Sni.SystemTray.items.values.filter(function(i) { return i && i.status !== Sni.Status.Passive; }) : []
                delegate: Item {
                    id: ti
                    required property var modelData
                    width: 18; height: 18
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                    IconImage {
                        anchors.fill: parent
                        source: ti.modelData.icon
                        asynchronous: true
                        opacity: tih.hovered || (Panels.current === "tray" && Panels.trayItem === ti.modelData) ? 1 : 0.82
                        scale: tih.hovered ? 1.08 : 1
                        Behavior on scale { NumberAnimation { duration: Motion.quick } }
                    }
                    Node {
                        x: 12; y: -2
                        visible: ti.modelData.status === Sni.Status.NeedsAttention
                        core: 4; halo: 3
                        color: Theme.alert
                        breathing: true
                    }
                    HoverHandler { id: tih; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onTapped: function(point, button) {
                            const it = ti.modelData;
                            if (button === Qt.MiddleButton) it.secondaryActivate();
                            else if (button === Qt.RightButton || it.onlyMenu) { if (it.hasMenu) Panels.openTray(it); }
                            else it.activate();
                        }
                    }
                    WheelHandler {
                        onWheel: function(event) { ti.modelData.scroll(event.angleDelta.y, false); }
                    }
                }
            }
        }

        Item {
            visible: Settings.bar.layout && Keyboard.multiple
            width: layoutText.implicitWidth + 14
            height: parent.height
            Rectangle {
                anchors.centerIn: parent
                width: parent.width; height: 20; radius: 6
                color: layoutHover.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.09)
            }
            Text {
                id: layoutText
                anchors.centerIn: parent
                text: Keyboard.label
                font.family: Tokens.fontMono; font.pixelSize: 10; font.letterSpacing: 1
                renderType: Text.NativeRendering
                color: layoutHover.hovered ? Theme.text : Theme.dim
            }
            HoverHandler { id: layoutHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Keyboard.next() }
        }

        Item {
            id: cluster
            width: icons.implicitWidth
            height: parent.height

            Row {
                id: icons
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Glyph {
                    path: Net.kind === "wired" ? Icons.wired : Net.online ? Icons.wifi : Icons.wifiOff
                    faint: !Net.online
                    hot: clusterHover.hovered
                }
                Glyph {
                    visible: Net.btPresent
                    path: Icons.bluetooth
                    lit: Net.btConnected.length > 0
                    faint: !Net.btEnabled
                    hot: clusterHover.hovered
                }
                Glyph {
                    path: Audio.muted ? Icons.volumeMute : Audio.volume < 0.34 ? Icons.volumeLow : Icons.volume
                    faint: Audio.muted
                    hot: clusterHover.hovered
                }
                Item {
                    width: 16; height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    Glyph {
                        anchors.centerIn: parent
                        path: Notifs.dnd ? Icons.bellOff : Icons.bell
                        faint: Notifs.dnd
                        hot: clusterHover.hovered
                    }
                    Node {
                        x: 10; y: -1
                        visible: Notifs.unread > 0 && !Notifs.dnd
                        core: 4
                        halo: 3
                        breathing: true
                    }
                }
                Row {
                    visible: Battery.present && Settings.bar.battery
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Glyph {
                        path: Battery.icon
                        lit: Battery.charging
                        hot: clusterHover.hovered
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Battery.percent + "%"
                        font.family: Tokens.fontMono; font.pixelSize: 11
                        renderType: Text.NativeRendering
                        color: Battery.level < 0.15 && !Battery.charging ? Theme.alert : Theme.dim
                    }
                }
            }

            Filament {
                y: parent.height - 6
                x: (parent.width - this.width) / 2
                width: parent.width + 6
                spread: 3
                intensity: ["control", "network", "bluetooth", "mixer"].indexOf(Panels.current) >= 0 ? 1 : 0
                visible: this.intensity > 0
                Behavior on intensity {
                    NumberAnimation { duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
                }
            }

            HoverHandler { id: clusterHover }
            TapHandler { onTapped: Panels.toggle("control") }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(event) { Audio.changeVolume(event.angleDelta.y > 0 ? 0.05 : -0.05); }
            }
        }

        Rectangle {
            width: 1; height: 14
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(Theme.line, 0.9)
        }

        Item {
            id: clockBox
            width: clockRow.implicitWidth
            height: parent.height

            SystemClock {
                id: clock
                precision: Settings.appearance.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
            }

            Row {
                id: clockRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "ddd d")
                    font.family: Tokens.fontMono
                    font.pixelSize: 11
                    font.letterSpacing: 1
                    renderType: Text.NativeRendering
                    color: clockHover.hovered ? Theme.dim : Theme.mute
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, Settings.barTimeFormat)
                    font.family: Tokens.fontSans
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    color: Theme.text
                }
            }

            Filament {
                y: parent.height - 6
                x: (parent.width - this.width) / 2
                width: parent.width + 6
                spread: 3
                intensity: Panels.current === "dashboard" ? 1 : 0
                visible: this.intensity > 0
                Behavior on intensity {
                    NumberAnimation { duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
                }
            }

            HoverHandler { id: clockHover }
            TapHandler { onTapped: Panels.toggle("dashboard") }
        }
    }
}
