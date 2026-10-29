import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.core
import qs.components
import qs.services

Item {
    id: root

    property var host: null

    implicitWidth: 540
    implicitHeight: 254

    readonly property var kinds: [
        { name: "Region", note: "drag across the screen", kind: "region", run: function() { Shot.region(); } },
        { name: "Window", note: "the focused window", kind: "window", run: function() { Shot.window(); } },
        { name: "Screen", note: "all of this monitor", kind: "screen", run: function() { Shot.screen(); } }
    ]
    property int selected: 0

    function takeFocus(): void { keys.forceActiveFocus(); }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onLeftPressed: root.selected = (root.selected + 2) % 3
        Keys.onRightPressed: root.selected = (root.selected + 1) % 3
        Keys.onTabPressed: root.selected = (root.selected + 1) % 3
        Keys.onReturnPressed: root.kinds[root.selected].run()
        Keys.onPressed: function(e) {
            const n = e.key - Qt.Key_1;
            if (n >= 0 && n < 3) {
                root.kinds[n].run();
                e.accepted = true;
            }
        }
    }

    Row {
        id: heading
        spacing: 12
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: "Screenshot"
                font.family: Tokens.fontSans; font.pixelSize: 17; font.weight: Font.Medium
                renderType: Text.NativeRendering
                color: Theme.text
            }
            Text {
                text: "Saved to ~/Pictures/Screenshots and copied"
                font.family: Tokens.fontSans; font.pixelSize: 12
                renderType: Text.NativeRendering
                color: Theme.mute
            }
        }
    }

    Row {
        id: tiles
        y: heading.height + 20
        spacing: 12

        Repeater {
            model: root.kinds
            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool chosen: tile.index === root.selected
                readonly property color ink: tile.chosen ? Theme.glow : Theme.mute
                width: (root.width - 24) / 3
                height: 156

                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: tile.chosen ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(1, 1, 1, 0.03)
                    Behavior on color { ColorAnimation { duration: Motion.quick } }
                }

                Item {
                    id: pic
                    width: 120; height: 72
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 18

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: tile.modelData.kind === "screen" ? Qt.alpha(tile.ink, 0.14) : Qt.rgba(1, 1, 1, 0.03)
                        border.width: tile.modelData.kind === "screen" ? 1.5 : 1
                        border.color: tile.modelData.kind === "screen" ? tile.ink : Qt.rgba(1, 1, 1, 0.12)
                    }
                    Rectangle { x: 6; y: 5; width: parent.width - 12; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.08) }

                    Rectangle {
                        visible: tile.modelData.kind === "window"
                        x: 8; y: 14; width: 56; height: 50; radius: 4
                        color: Qt.alpha(tile.ink, 0.16)
                        border.width: 1.5; border.color: tile.ink
                    }
                    Rectangle {
                        visible: tile.modelData.kind === "window"
                        x: 70; y: 14; width: 42; height: 50; radius: 4
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                    }
                    Rectangle {
                        visible: tile.modelData.kind === "region"
                        anchors.fill: parent
                        radius: 7
                        color: Qt.rgba(0, 0, 0, 0.25)
                    }
                    Shape {
                        visible: tile.modelData.kind === "region"
                        anchors.fill: parent
                        ShapePath {
                            strokeColor: tile.ink
                            strokeWidth: 1.2
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [3, 2.5]
                            fillColor: Qt.alpha(tile.ink, 0.14)
                            PathSvg { path: "M 30 20 H 92 V 58 H 30 Z" }
                        }
                        ShapePath {
                            strokeColor: tile.ink
                            strokeWidth: 2
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathSvg { path: "M 30 26 V 20 H 36 M 86 20 H 92 V 26 M 92 52 V 58 H 86 M 36 58 H 30 V 52" }
                        }
                    }
                    Icon {
                        visible: tile.modelData.kind !== "screen"
                        x: tile.modelData.kind === "region" ? 84 : 46
                        y: tile.modelData.kind === "region" ? 50 : 40
                        path: Icons.cursor; size: 16
                        color: Theme.text
                    }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: pic.bottom; anchors.topMargin: 14
                    spacing: 3
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.name
                        font.family: Tokens.fontSans; font.pixelSize: 14; font.weight: Font.Medium
                        renderType: Text.NativeRendering
                        color: tile.chosen ? Theme.text : Theme.dim
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.note
                        font.family: Tokens.fontSans; font.pixelSize: 11
                        renderType: Text.NativeRendering
                        color: Theme.mute
                    }
                }

                HoverHandler {
                    id: th
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (this.hovered) root.selected = tile.index
                }
                TapHandler { onTapped: tile.modelData.run() }
            }
        }
    }

    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 22
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 6
            Icon { anchors.verticalCenter: parent.verticalCenter; path: Icons.record; size: 13; color: rh.hovered ? Theme.glow : Theme.dim }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Record a video instead"
                font.family: Tokens.fontSans; font.pixelSize: 12
                font.underline: rh.hovered
                renderType: Text.NativeRendering
                color: rh.hovered ? Theme.text : Theme.dim
            }
            HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Panels.show("record") }
        }
    }
}
