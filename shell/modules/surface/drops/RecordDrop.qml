import QtQuick
import qs.core
import qs.components
import qs.services

Item {
    id: root

    property var host: null

    implicitWidth: 520
    implicitHeight: col.implicitHeight

    function takeFocus(): void { keys.forceActiveFocus(); }

    readonly property var choices: [
        { name: "Region", note: "drag on the screen", icon: Icons.region, key: "1", run: function() { Recorder.region(); } },
        { name: "Window", note: Recorder.tool === "gsr" ? "pick one" : "the focused one", icon: Icons.window, key: "2", run: function() { Recorder.window(); } },
        { name: "Screen", note: "this monitor", icon: Icons.screen, key: "3", run: function() { Recorder.screen(); } }
    ]

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
            const i = ["1", "2", "3"].indexOf(event.text);
            if (i >= 0) { root.choices[i].run(); event.accepted = true; }
        }
    }

    component Check: Item {
        id: c
        property string label: ""
        property string icon: ""
        property bool on: false
        signal toggled()
        width: row.implicitWidth + 24; height: 32
        Rectangle {
            anchors.fill: parent; radius: 16
            color: c.on ? Qt.alpha(Theme.glow, 0.13) : ch.hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.035)
        }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Icon { anchors.verticalCenter: parent.verticalCenter; path: c.icon; size: 14; color: c.on ? Theme.glowHi : Theme.dim }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: c.label
                font.family: Tokens.fontSans; font.pixelSize: 12
                renderType: Text.NativeRendering
                color: c.on ? Theme.text : Theme.dim
            }
        }
        HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: c.toggled() }
    }

    Column {
        id: col
        width: parent.width
        spacing: 16

        Item {
            width: parent.width; height: 18
            Text {
                text: "Record the screen"
                font.family: Tokens.fontSans; font.pixelSize: 12; font.weight: Font.Medium
                renderType: Text.NativeRendering
                color: Theme.glow
            }
            Text {
                anchors.right: parent.right
                text: Recorder.available ? Settings.recorder.fps + " fps"
                                         : "install gpu-screen-recorder"
                font.family: Tokens.fontMono; font.pixelSize: 10
                renderType: Text.NativeRendering
                color: Recorder.available ? Theme.mute : Theme.alert
            }
        }

        Row {
            spacing: 10
            Repeater {
                model: root.choices
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    width: (col.width - 20) / 3
                    height: 112
                    radius: Tokens.radiusField + 2
                    opacity: Recorder.available ? 1 : 0.45
                    color: cardHover.hovered ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.035)
                    Behavior on color { ColorAnimation { duration: Motion.quick } }

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 26
                        path: card.modelData.icon
                        size: 22
                        color: cardHover.hovered ? Theme.alert : Theme.dim
                    }
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 66
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.modelData.name
                            font.family: Tokens.fontSans; font.pixelSize: 13; font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.modelData.note
                            font.family: Tokens.fontMono; font.pixelSize: 10
                            renderType: Text.NativeRendering
                            color: Theme.mute
                        }
                    }
                    HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { enabled: Recorder.available; onTapped: card.modelData.run() }
                }
            }
        }

        Row {
            spacing: 8
            Check {
                label: "System sound"; icon: Icons.volume
                on: Settings.recorder.systemAudio
                onToggled: Settings.recorder.systemAudio = !Settings.recorder.systemAudio
            }
            Check {
                label: "Microphone"; icon: Icons.mic
                on: Settings.recorder.microphone
                onToggled: Settings.recorder.microphone = !Settings.recorder.microphone
            }
            Check {
                label: "Cursor"; icon: Icons.cursor
                on: Settings.recorder.cursor
                onToggled: Settings.recorder.cursor = !Settings.recorder.cursor
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "Saved to " + Recorder.dir.replace(Paths.home, "~") + ". Super+Shift+R again stops it."
            font.family: Tokens.fontMono; font.pixelSize: 10
            renderType: Text.NativeRendering
            color: Theme.mute
        }
    }
}
