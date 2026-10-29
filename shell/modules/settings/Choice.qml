import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // [{ value, label }]
    property var options: []
    property var value
    signal picked(var value)

    readonly property int current: {
        for (let i = 0; i < root.options.length; i++)
            if (root.options[i].value === root.value) return i;
        return -1;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: 26

    Row {
        id: row
        spacing: 18
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            id: rep
            model: root.options
            delegate: Text {
                required property var modelData
                required property int index
                text: modelData.label
                font.family: Tokens.fontSans
                font.pixelSize: 13
                font.weight: index === root.current ? Font.Medium : Font.Normal
                renderType: Text.NativeRendering
                color: index === root.current ? Theme.text : h.hovered ? Theme.dim : Theme.mute
                Behavior on color { ColorAnimation { duration: Motion.quick } }
                HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        root.value = modelData.value;
                        root.picked(modelData.value);
                    }
                }
            }
        }
    }

    Spring { id: mx; kind: "nudge"; target: root.markX }
    Spring { id: mw; kind: "nudge"; target: root.markW }
    readonly property Item chosen: rep.count > 0 && root.current >= 0 ? rep.itemAt(root.current) : null
    readonly property real markX: root.chosen ? root.chosen.x : 0
    readonly property real markW: root.chosen ? root.chosen.width : 0

    Filament {
        x: mx.value
        width: mw.value
        y: root.height - 4
        spread: 2
        visible: root.current >= 0
    }
}
