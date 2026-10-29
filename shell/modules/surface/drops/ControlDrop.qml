import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.core
import qs.components
import qs.services
import qs.modules.player

Item {
    id: root

    property var host: null

    implicitWidth: 392
    implicitHeight: col.implicitHeight

    Component.onCompleted: {
        Session.wantUptime = true;
        Notifs.markAllSeen();
    }
    Component.onDestruction: Session.wantUptime = false

    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property string profileName: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver: return "Power saver";
        case PowerProfile.Performance: return "Performance";
        default: return "Balanced";
        }
    }
    readonly property string profileIcon: PowerProfiles.profile === PowerProfile.PowerSaver ? Icons.powerSaver
        : PowerProfiles.profile === PowerProfile.Performance ? Icons.performance : Icons.balanced
    function cycleProfile(): void {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced; break;
        case PowerProfile.Balanced:
            PowerProfiles.profile = PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver;
            break;
        default: PowerProfiles.profile = PowerProfile.PowerSaver; break;
        }
    }

    component RoundButton: Item {
        id: rb
        property string icon: ""
        property bool danger: false
        signal clicked()
        width: 34; height: 34
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: rbh.hovered ? (rb.danger ? Qt.alpha(Theme.alert, 0.16) : Qt.rgba(1, 1, 1, 0.07)) : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.quick } }
        }
        Icon {
            anchors.centerIn: parent
            path: rb.icon
            size: 16
            color: rbh.hovered ? (rb.danger ? Theme.alert : Theme.text) : Theme.dim
        }
        HoverHandler { id: rbh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: rb.clicked() }
    }

    component Tile: Rectangle {
        id: tile
        property string icon: ""
        property string label: ""
        property string detail: ""
        property bool on: false
        property bool hot: false            // recording: on, and red
        property bool available: true
        property bool hasMore: false
        signal clicked()
        signal more()

        height: 60
        radius: Tokens.radiusField + 2
        color: tile.on ? Qt.alpha(tile.hot ? Theme.alert : Theme.glow, th.hovered ? 0.15 : 0.11)
             : Qt.rgba(1, 1, 1, th.hovered && tile.available ? 0.06 : 0.035)
        opacity: tile.available ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }

        Icon {
            id: disc
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            path: tile.icon
            size: 18
            color: tile.on ? (tile.hot ? Theme.alert : Theme.glowHi) : Theme.dim
        }
        Column {
            x: disc.x + disc.width + 14
            anchors.verticalCenter: parent.verticalCenter
            width: tile.width - x - (tile.hasMore ? 30 : 10)
            spacing: 1
            Text {
                width: parent.width
                text: tile.label
                elide: Text.ElideRight
                font.family: Tokens.fontSans; font.pixelSize: 13; font.weight: Font.Medium
                renderType: Text.NativeRendering
                color: Theme.text
            }
            Text {
                width: parent.width
                text: tile.detail
                elide: Text.ElideRight
                font.family: Tokens.fontSans; font.pixelSize: 12
                renderType: Text.NativeRendering
                color: tile.on ? Theme.dim : Theme.mute
            }
        }

        HoverHandler { id: th; cursorShape: tile.available ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler {
            enabled: tile.available
            onTapped: function(point) {
                if (!tile.hasMore || point.position.x < tile.width - 30) tile.clicked();
            }
        }
        Item {
            visible: tile.hasMore && tile.available
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 30
            Icon {
                anchors.centerIn: parent
                path: Icons.chevronRight
                size: 15
                color: mh.hovered ? Theme.text : Theme.mute
            }
            HoverHandler { id: mh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: tile.more() }
        }
    }

    component Caps: Text {
        font.family: Tokens.fontSans
        font.pixelSize: 12
        font.weight: Font.Medium
        renderType: Text.NativeRendering
        color: Theme.mute
    }

    Column {
        id: col
        width: parent.width
        spacing: 0

        Item {
            width: parent.width; height: 44

            Item {
                id: face
                width: avatar.status === Image.Ready ? 40 : 0; height: 40
                anchors.verticalCenter: parent.verticalCenter
                FileView {
                    id: faceFile
                    path: Paths.home + "/.face"
                    printErrors: false
                    property bool exists: false
                    onLoaded: faceFile.exists = true
                    onLoadFailed: faceFile.exists = false
                }
                Image {
                    id: avatar
                    width: 40; height: 40
                    source: faceFile.exists ? Paths.fileUrl(Paths.home + "/.face") : ""
                    sourceSize.width: 80; sourceSize.height: 80
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: avatar
                    source: avatar
                    visible: avatar.status === Image.Ready
                    maskEnabled: true
                    maskSource: avatarMask
                }
                Item {
                    id: avatarMask
                    anchors.fill: avatar
                    layer.enabled: true
                    visible: false
                    Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
                }
            }

            Column {
                x: face.width > 0 ? face.width + 12 : 0
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - buttons.width - 8
                spacing: 2
                Text {
                    width: parent.width
                    text: Qt.formatDateTime(clock.date, "dddd d MMMM")
                    elide: Text.ElideRight
                    font.family: Tokens.fontSans; font.pixelSize: 15; font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    color: Theme.text
                }
                Row {
                    spacing: 6
                    Icon {
                        visible: Battery.present && Settings.bar.battery
                        anchors.verticalCenter: parent.verticalCenter
                        path: Battery.icon
                        size: 14
                        color: Battery.level < 0.15 && !Battery.charging ? Theme.alert : Theme.glow
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: [Battery.present && Settings.bar.battery
                                   ? Battery.percent + "%" + (Battery.estimate !== "" ? ", " + Battery.estimate : "") : "",
                               Session.uptime].filter(function(s) { return s !== ""; }).join(", ")
                        font.family: Tokens.fontSans; font.pixelSize: 12
                        renderType: Text.NativeRendering
                        color: Theme.mute
                    }
                }
            }

            Row {
                id: buttons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                RoundButton { icon: Icons.lock; onClicked: { Panels.close(); Session.lock(); } }
                RoundButton { icon: Icons.settings; onClicked: { Panels.close(); Panels.settingsOpen = true; } }
                RoundButton { icon: Icons.power; danger: true; onClicked: Panels.show("power") }
            }
        }

        Item { width: 1; height: 20 }

        Row {
            width: parent.width
            spacing: 8
            Level {
                width: parent.width - 44
                enabled: Audio.ready
                icon: Audio.muted ? Icons.volumeMute : Audio.volume < 0.34 ? Icons.volumeLow : Icons.volume
                value: Audio.volume
                off: Audio.muted
                text: Audio.ready ? (Audio.muted ? "muted" : Math.round(Audio.volume * 100) + "%") : "no audio"
                onMoved: function(v) { Audio.setVolume(v); if (Audio.muted && v > 0) Audio.toggleMute(); }
                onIconClicked: Audio.toggleMute()
            }
            RoundButton {
                width: 36; height: 36
                icon: Icons.mixer
                onClicked: Panels.show("mixer")
            }
        }
        Item {
            width: parent.width; height: Audio.ready ? 22 : 0
            visible: Audio.ready
            Text {
                x: 14; y: 6
                width: parent.width - 60
                text: Audio.sinkName
                elide: Text.ElideRight
                font.family: Tokens.fontSans; font.pixelSize: 12
                renderType: Text.NativeRendering
                color: sinkHover.hovered ? Theme.dim : Theme.mute
                HoverHandler { id: sinkHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Panels.show("mixer") }
            }
        }
        Item { width: 1; height: Brightness.available ? 8 : 0 }
        Level {
            width: parent.width
            visible: Brightness.available
            icon: Brightness.level < 0.4 ? Icons.brightnessLow : Icons.brightness
            value: Brightness.level
            onMoved: function(v) { Brightness.set(Math.round(v * 100)); }
        }

        Item { width: 1; height: 18 }

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            readonly property real cell: (col.width - 8) / 2

            Tile {
                width: parent.cell
                icon: Net.kind === "wired" ? Icons.wired : Net.online ? Icons.wifi : Icons.wifiOff
                label: Net.kind === "wired" ? "Ethernet" : "Wi-Fi"
                detail: Net.online ? Net.name : (Net.hasWifiHardware ? (Net.wifiEnabled ? "Not connected" : "Off") : "Offline")
                on: Net.online
                available: Net.kind === "wired" || Net.hasWifiHardware
                hasMore: true
                onClicked: if (Net.kind !== "wired") Net.setWifi(!Net.wifiEnabled)
                onMore: Panels.show("network")
            }
            Tile {
                width: parent.cell
                icon: !Net.btEnabled ? Icons.bluetoothOff : Net.btConnected.length > 0 ? Icons.bluetoothOn : Icons.bluetooth
                label: "Bluetooth"
                detail: !Net.btPresent ? "No adapter"
                      : !Net.btEnabled ? "Off"
                      : Net.btConnected.length > 0 ? (Net.btConnected[0].name || "Connected")
                      : "On"
                on: Net.btEnabled
                available: Net.btPresent
                hasMore: true
                onClicked: Net.setBluetooth(!Net.btEnabled)
                onMore: Panels.show("bluetooth")
            }
            Tile {
                width: parent.cell
                icon: Icons.nightLight
                label: "Night light"
                detail: !NightLight.available ? "Needs hyprsunset"
                      : Settings.nightLight.scheduled ? Settings.nightLight.from + "–" + Settings.nightLight.to
                      : NightLight.active ? NightLight.temperature + " K" : "Off"
                on: NightLight.active
                available: NightLight.available
                onClicked: NightLight.toggle()
            }
            Tile {
                width: parent.cell
                icon: Notifs.dnd ? Icons.bellOff : Icons.bell
                label: "Do not disturb"
                detail: Notifs.dnd ? "On" : "Off"
                on: Notifs.dnd
                onClicked: Notifs.setDnd(!Notifs.dnd)
            }
            Tile {
                width: parent.cell
                icon: Icons.caffeine
                label: "Caffeine"
                detail: Idle.caffeine ? "Staying awake" : "Off"
                on: Idle.caffeine
                onClicked: Idle.setCaffeine(!Idle.caffeine)
            }
            Tile {
                width: parent.cell
                icon: root.profileIcon
                label: "Power"
                detail: root.profileName
                on: PowerProfiles.profile !== PowerProfile.Balanced
                onClicked: root.cycleProfile()
            }
            Tile {
                width: parent.cell
                icon: Recorder.recording ? Icons.stop : Icons.record
                label: Recorder.recording ? "Recording" : "Record"
                detail: !Recorder.available ? "Needs gpu-screen-recorder"
                      : Recorder.recording ? Recorder.clock + ", click to stop" : "Screen, window or region"
                on: Recorder.recording
                hot: Recorder.recording
                available: Recorder.available
                hasMore: !Recorder.recording
                onClicked: Recorder.recording ? Recorder.stop() : Panels.show("record")
                onMore: Panels.show("record")
            }
            Tile {
                width: parent.cell
                visible: Keyboard.multiple
                icon: Icons.keyboard
                label: "Keyboard"
                detail: Keyboard.layouts.map(function(l, i) { return i === Keyboard.index ? l.toUpperCase() : l; }).join("  ")
                on: true
                onClicked: Keyboard.next()
            }
            Tile {
                width: parent.cell
                visible: !Keyboard.multiple
                icon: Icons.screenshot
                label: "Screenshot"
                detail: "Region, window or screen"
                onClicked: Panels.show("capture")
            }
        }

        Item {
            width: parent.width
            height: Players.hasPlayer && Players.title !== "" ? 18 + card.height : 0
            visible: this.height > 0

            Rectangle {
                id: card
                y: 18
                width: parent.width
                height: 80
                radius: Tokens.radiusField + 2
                color: Qt.rgba(1, 1, 1, 0.035)

                Item {
                    id: art
                    x: 10; y: 10
                    width: 60; height: 60
                    Image {
                        id: artImg
                        anchors.fill: parent
                        source: Players.artUrl
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 120; sourceSize.height: 120
                        asynchronous: true
                        visible: false
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 10
                        color: Theme.surfaceSlate
                        visible: artImg.status !== Image.Ready
                        Icon { anchors.centerIn: parent; path: Icons.music; size: 20; color: Theme.mute }
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: artImg
                        visible: artImg.status === Image.Ready
                        maskEnabled: true
                        maskSource: artMask
                    }
                    Item {
                        id: artMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false
                        Rectangle { anchors.fill: parent; radius: 10; color: "black" }
                    }
                    TapHandler { onTapped: Panels.show("player") }
                }
                Column {
                    anchors { left: art.right; leftMargin: 12; right: transport.left; rightMargin: 10; top: art.top; topMargin: 2 }
                    spacing: 1
                    Text {
                        width: parent.width
                        text: Players.title
                        elide: Text.ElideRight
                        font.family: Tokens.fontSans; font.pixelSize: 14; font.weight: Font.Medium
                        renderType: Text.NativeRendering
                        color: Theme.text
                    }
                    Text {
                        width: parent.width
                        text: Players.artist !== "" ? Players.artist : Players.identity
                        elide: Text.ElideRight
                        font.family: Tokens.fontSans; font.pixelSize: 12
                        renderType: Text.NativeRendering
                        color: Theme.dim
                    }
                }
                Scrubber {
                    anchors { left: art.right; leftMargin: 12; right: parent.right; rightMargin: 14; bottom: art.bottom; bottomMargin: 2 }
                }
                Row {
                    id: transport
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    y: 12
                    spacing: 2
                    Repeater {
                        model: [
                            { icon: Icons.previous, run: function() { Players.previous(); }, enabled: Players.canGoPrevious },
                            { icon: Players.playing ? Icons.pause : Icons.play, run: function() { Players.playPause(); }, enabled: true },
                            { icon: Icons.next, run: function() { Players.next(); }, enabled: Players.canGoNext }
                        ]
                        delegate: Item {
                            required property var modelData
                            width: 28; height: 28
                            Rectangle {
                                anchors.fill: parent; radius: 14
                                color: tph.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            }
                            Icon {
                                anchors.centerIn: parent
                                path: parent.modelData.icon
                                size: 15
                                color: !parent.modelData.enabled ? Theme.line : tph.hovered ? Theme.text : Theme.dim
                            }
                            HoverHandler { id: tph; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: if (parent.modelData.enabled) parent.modelData.run() }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 20 }
        Item {
            width: parent.width; height: 18
            Caps { text: Notifs.history.length === 0 ? "No notifications" : "Notifications" }
            Row {
                anchors.right: parent.right
                spacing: 6
                visible: Notifs.history.length > 0
                Icon { anchors.verticalCenter: parent.verticalCenter; path: Icons.trash; size: 12; color: clh.hovered ? Theme.text : Theme.mute }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clear"
                    font.family: Tokens.fontSans; font.pixelSize: 12
                    renderType: Text.NativeRendering
                    color: clh.hovered ? Theme.text : Theme.dim
                }
                HoverHandler { id: clh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Notifs.clearHistory() }
            }
        }
        Item { width: 1; height: 8 }
        NotificationList {
            width: parent.width
            maxGroups: 4
        }
    }
}
