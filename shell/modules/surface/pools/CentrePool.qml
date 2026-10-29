import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services

Item {
    id: root

    readonly property bool hasMusic: Settings.bar.nowPlaying && Players.hasPlayer && Players.title !== ""
    property bool showLevel: false

    readonly property string mode: root.showLevel ? "level" : root.hasMusic ? "music" : ""
    readonly property bool present: root.mode !== ""
    readonly property real depth: root.mode === "level" ? 70 : 0

    implicitHeight: 30
    implicitWidth: root.mode === "level" ? 360
                 : root.mode === "music" ? Math.min(380, music.implicitWidth)
                 : 0

    // ignore what the devices report at startup
    property bool armed: false
    Timer {
        interval: 3000
        running: true
        onTriggered: root.armed = true
    }
    property string levelKind: "volume"        // volume | mic | brightness | layout
    function flash(kind: string): void {
        if (!root.armed) return;
        root.levelKind = kind;
        root.showLevel = true;
        hold.restart();
    }
    Connections {
        target: Audio
        function onVolumeChanged() { if (Audio.ready) root.flash("volume"); }
        function onMutedChanged() { if (Audio.ready) root.flash("volume"); }
        function onMicMutedChanged() { if (Audio.micReady) root.flash("mic"); }
    }
    Connections {
        target: Brightness
        function onStepped() { root.flash("brightness"); }
    }
    Connections {
        target: Keyboard
        function onIndexChanged() { if (Keyboard.multiple) root.flash("layout"); }
    }
    Timer {
        id: hold
        interval: 1500
        onTriggered: root.showLevel = false
    }

    readonly property bool isMuted: root.levelKind === "volume" ? Audio.muted : root.levelKind === "mic" ? Audio.micMuted : false
    readonly property real levelValue: root.levelKind === "brightness" ? Brightness.level
                                     : root.levelKind === "mic" ? (Audio.micMuted ? 0 : Math.min(1, Audio.micVolume))
                                     : root.levelKind === "volume" ? (Audio.muted ? 0 : Math.min(1, Audio.volume)) : 0
    readonly property int percent: Math.round((root.levelKind === "brightness" ? Brightness.level
                                             : root.levelKind === "mic" ? Audio.micVolume : Audio.volume) * 100)
    readonly property string levelIcon: {
        switch (root.levelKind) {
        case "brightness": return Brightness.level < 0.4 ? Icons.brightnessLow : Icons.brightness;
        case "mic": return Audio.micMuted ? Icons.micOff : Icons.mic;
        case "layout": return Icons.keyboard;
        default: return Audio.muted ? Icons.volumeMute : Audio.volume < 0.4 ? Icons.volumeLow : Icons.volume;
        }
    }
    readonly property string levelTitle: {
        switch (root.levelKind) {
        case "brightness": return "Brightness";
        case "mic": return Audio.micMuted ? "Microphone off" : "Microphone";
        case "layout": return "Keyboard";
        default: return Audio.muted ? "Muted" : "Volume";
        }
    }
    readonly property string levelNote: {
        if (root.levelKind === "volume") return Audio.sinkName;
        if (root.levelKind === "layout") return Keyboard.keymap;
        return "";
    }

    Item {
        id: music
        anchors.fill: parent
        opacity: root.mode === "music" ? 1 : 0
        visible: this.opacity > 0
        implicitWidth: musicRow.implicitWidth + 36

        Behavior on opacity {
            NumberAnimation { duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
        }

        Row {
            id: musicRow
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -1
            spacing: 10

            Rectangle {
                width: 20; height: 20; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.surfaceSlate
                clip: true
                Image {
                    anchors.fill: parent
                    source: Players.artUrl
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 40; sourceSize.height: 40
                    asynchronous: true
                    visible: this.status === Image.Ready
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Players.title
                width: Math.min(this.implicitWidth, 190)
                elide: Text.ElideRight
                font.family: Tokens.fontSans
                font.pixelSize: 13
                font.weight: Font.Medium
                renderType: Text.NativeRendering
                color: Theme.text
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Players.artist
                visible: Players.artist !== ""
                width: Math.min(this.implicitWidth, 120)
                elide: Text.ElideRight
                font.family: Tokens.fontSans
                font.pixelSize: 12
                renderType: Text.NativeRendering
                color: Theme.mute
            }
        }

        Item {
            x: 18; width: parent.width - 36
            y: parent.height - 2; height: 1
            Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.line, 0.7) }
            Rectangle {
                height: 1
                width: parent.width * Players.progress
                color: Players.accent
                Behavior on width { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
            }
        }

        HoverHandler { id: musicHover }
        TapHandler { onTapped: Panels.toggle("player") }
        // middle click: play/pause without opening anything
        TapHandler {
            acceptedButtons: Qt.MiddleButton
            onTapped: Players.playPause()
        }
    }

    Item {
        id: card
        anchors.fill: parent
        opacity: root.mode === "level" ? 1 : 0
        visible: this.opacity > 0
        scale: root.mode === "level" ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }
        Behavior on scale { NumberAnimation { duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }

        readonly property color tint: root.isMuted ? Theme.mute : Theme.glow

        Icon {
            id: disc
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22
            path: root.levelIcon
            size: 22
            color: root.isMuted ? Theme.mute : Theme.glowHi
        }

        Item {
            id: words
            anchors { left: disc.right; leftMargin: 16; right: big.left; rightMargin: 12 }
            // name on top, bar under it, the pair centred
            y: Math.round((card.height - (height + 7 + 8)) / 2)
            height: 18
            Text {
                id: title
                anchors.verticalCenter: parent.verticalCenter
                text: root.levelTitle
                font.family: Tokens.fontSans; font.pixelSize: 13; font.weight: Font.Medium
                renderType: Text.NativeRendering
                color: Theme.text
            }
            Text {
                anchors { left: title.right; leftMargin: 8; right: parent.right; verticalCenter: parent.verticalCenter }
                text: root.levelNote
                elide: Text.ElideRight
                font.family: Tokens.fontSans; font.pixelSize: 12
                renderType: Text.NativeRendering
                color: Theme.mute
            }
        }

        Item {
            id: bar
            visible: root.levelKind !== "layout"
            anchors { left: words.left; right: big.left; rightMargin: 12; top: words.bottom; topMargin: 7 }
            height: 8
            Rectangle {
                anchors.fill: parent
                radius: 4
                color: Qt.rgba(1, 1, 1, 0.07)
            }
            Repeater {
                model: 9
                delegate: Rectangle {
                    required property int index
                    x: bar.width * (index + 1) / 10 - 0.5
                    width: 1; height: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.08)
                }
            }
            Rectangle {
                id: fill
                height: parent.height
                width: Math.max(height, bar.width * root.levelValue)
                visible: root.levelValue > 0.001
                radius: 4
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.alpha(card.tint, 0.35) }
                    GradientStop { position: 1.0; color: card.tint }
                }
                Behavior on width { NumberAnimation { duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }
            }
            Node {
                anchors.verticalCenter: parent.verticalCenter
                x: fill.width - width / 2 - 2
                visible: fill.visible
                core: 6; halo: 6
                color: Theme.glowHi
            }
        }
        Row {
            visible: root.levelKind === "layout"
            anchors { left: words.left; top: words.bottom; topMargin: 4 }
            spacing: 6
            Repeater {
                model: Keyboard.layouts
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool on: index === Keyboard.index
                    width: code.implicitWidth + 16; height: 18; radius: 9
                    color: on ? Qt.alpha(Theme.glow, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: on ? Qt.alpha(Theme.glow, 0.6) : "transparent"
                    Text {
                        id: code
                        anchors.centerIn: parent
                        text: String(modelData).toUpperCase()
                        font.family: Tokens.fontMono; font.pixelSize: 10; font.weight: Font.Medium
                        renderType: Text.NativeRendering
                        color: parent.on ? Theme.glowHi : Theme.dim
                    }
                }
            }
        }

        Row {
            id: big
            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
            Text {
                anchors.baseline: parent.bottom
                text: root.levelKind === "layout" ? Keyboard.label
                    : root.isMuted ? "off" : root.percent
                font.family: Tokens.fontSans; font.pixelSize: 26; font.weight: Font.Light
                font.features: { "tnum": 1 }
                renderType: Text.NativeRendering
                color: root.isMuted ? Theme.mute : root.percent > 100 ? Theme.alert : Theme.text
            }
            Text {
                anchors.baseline: parent.bottom
                visible: root.levelKind !== "layout" && !root.isMuted
                text: "%"
                leftPadding: 2
                font.family: Tokens.fontSans; font.pixelSize: 13
                renderType: Text.NativeRendering
                color: Theme.mute
            }
            height: 30
        }
    }
}
