import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs.core
import qs.components
import qs.services

Item {
    id: root

    property var host: null

    implicitWidth: 400
    implicitHeight: col.implicitHeight

    Component.onCompleted: Mixer.watchers++
    Component.onDestruction: Mixer.watchers = Math.max(0, Mixer.watchers - 1)

    component Caps: Text {
        font.family: Tokens.fontSans
        font.pixelSize: 12
        font.weight: Font.Medium
        renderType: Text.NativeRendering
        color: Theme.glow
        topPadding: 4
        bottomPadding: 8
    }

    component Device: Item {
        id: d
        property var node: null
        property bool current: false
        property string icon: Icons.speaker
        signal picked()
        width: parent ? parent.width : 400
        height: 38

        Rectangle {
            anchors.fill: parent
            radius: Tokens.radiusField
            color: d.current ? Qt.alpha(Theme.glow, 0.09) : dh.hovered ? Qt.rgba(1, 1, 1, 0.045) : "transparent"
        }
        Icon {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            path: d.icon
            size: 16
            color: d.current ? Theme.glowHi : Theme.dim
        }
        Text {
            x: 40
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 80
            text: Mixer.label(d.node)
            elide: Text.ElideRight
            font.family: Tokens.fontSans; font.pixelSize: 13
            font.weight: d.current ? Font.Medium : Font.Normal
            renderType: Text.NativeRendering
            color: d.current ? Theme.text : Theme.dim
        }
        Icon {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: d.current
            path: Icons.check
            size: 15
            color: Theme.glowHi
        }
        HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: d.picked() }
    }

    component Stream: Column {
        id: s
        property var node: null
        width: parent ? parent.width : 400
        spacing: 6

        Item {
            width: parent.width
            height: 30
            IconImage {
                id: appIcon
                width: 22; height: 22
                anchors.verticalCenter: parent.verticalCenter
                source: Quickshell.iconPath(Mixer.iconName(s.node), true)
                visible: source != ""
                asynchronous: true
            }
            Icon {
                visible: !appIcon.visible
                anchors.verticalCenter: parent.verticalCenter
                path: Icons.music
                size: 18
                color: Theme.dim
            }
            Column {
                x: 32
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 32
                Text {
                    width: parent.width
                    text: Mixer.label(s.node)
                    elide: Text.ElideRight
                    font.family: Tokens.fontSans; font.pixelSize: 13; font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    color: Theme.text
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: Mixer.detail(s.node)
                    elide: Text.ElideRight
                    font.family: Tokens.fontMono; font.pixelSize: 10
                    renderType: Text.NativeRendering
                    color: Theme.mute
                }
            }
        }
        Level {
            width: parent.width
            icon: s.node && s.node.audio && s.node.audio.muted ? Icons.volumeMute : Icons.volume
            value: s.node && s.node.audio ? s.node.audio.volume : 0
            off: s.node && s.node.audio ? s.node.audio.muted : false
            onMoved: function(v) { Mixer.setVolume(s.node, v); }
            onIconClicked: Mixer.toggleMute(s.node)
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 4

        Caps { text: "Output" }
        Level {
            width: parent.width
            enabled: Audio.ready
            icon: Audio.muted ? Icons.volumeMute : Icons.volume
            value: Audio.volume
            off: Audio.muted
            onMoved: function(v) { Audio.setVolume(v); }
            onIconClicked: Audio.toggleMute()
        }
        Item { width: 1; height: 4 }
        Repeater {
            model: Mixer.outputs
            delegate: Device {
                required property var modelData
                node: modelData
                icon: /headphone|headset|bluez/i.test(Mixer.label(modelData) + " " + (modelData.name || "")) ? Icons.headphones : Icons.speaker
                current: modelData === Pipewire.defaultAudioSink
                onPicked: Mixer.useOutput(modelData)
            }
        }
        Text {
            visible: Mixer.outputs.length === 0
            text: Pipewire.ready ? "No outputs." : "PipeWire isn't running."
            font.family: Tokens.fontSans; font.pixelSize: 13
            renderType: Text.NativeRendering
            color: Theme.dim
        }

        Item { width: 1; height: 14 }
        Caps { text: Mixer.playing.length > 0 ? "Apps" : "Apps (nothing is playing)" }
        Column {
            width: parent.width
            spacing: 14
            Repeater {
                model: Mixer.playing
                delegate: Stream {
                    required property var modelData
                    node: modelData
                }
            }
        }

        Item { width: 1; height: 14 }
        Caps { text: "Input" }
        Level {
            width: parent.width
            enabled: Audio.micReady
            icon: Audio.micMuted ? Icons.micOff : Icons.mic
            value: Audio.micVolume
            off: Audio.micMuted
            text: !Audio.micReady ? "no microphone" : Audio.micMuted ? "muted" : Math.round(Audio.micVolume * 100) + "%"
            onMoved: function(v) { if (Audio.source && Audio.source.audio) Audio.source.audio.volume = v; }
            onIconClicked: Audio.toggleMicMute()
        }
        Item { width: 1; height: 4 }
        Repeater {
            model: Mixer.inputs
            delegate: Device {
                required property var modelData
                node: modelData
                icon: Icons.mic
                current: modelData === Pipewire.defaultAudioSource
                onPicked: Mixer.useInput(modelData)
            }
        }
        Text {
            visible: Mixer.listening.length > 0
            width: parent.width
            topPadding: 6
            wrapMode: Text.Wrap
            text: "In use by " + Mixer.listening.map(function(n) { return Mixer.label(n); })
                                        .filter(function(s, i, a) { return s !== "" && a.indexOf(s) === i; }).join(", ")
            font.family: Tokens.fontMono; font.pixelSize: 10
            renderType: Text.NativeRendering
            color: Theme.alert
        }
    }
}
