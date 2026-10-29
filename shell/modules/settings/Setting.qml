import QtQuick
import qs.core
import qs.components

Item {
    id: root

    property string label: ""
    property string note: ""
    default property alias control: slot.data

    readonly property bool stacked: root.width < 560

    width: parent ? parent.width : 600
    implicitHeight: (root.stacked ? text.implicitHeight + 12 + slot.height
                                  : Math.max(text.implicitHeight, slot.height)) + 30
    opacity: root.enabled ? 1 : 0.45

    Column {
        id: text
        x: 0
        y: root.stacked ? 15 : (root.height - 1 - text.implicitHeight) / 2
        width: root.stacked ? root.width : root.width - slot.width - 32
        spacing: 3
        TypeText {
            width: parent.width
            role: "title"
            text: root.label
            color: Theme.text
            font.pixelSize: 14
            wrapMode: Text.Wrap
        }
        TypeText {
            width: parent.width
            role: "body"
            text: root.note
            visible: text !== ""
            color: Theme.mute
            wrapMode: Text.Wrap
            font.pixelSize: 12
        }
    }

    Item {
        id: slot
        x: root.stacked ? 0 : root.width - slot.width
        y: root.stacked ? text.y + text.implicitHeight + 12 : (root.height - 1 - slot.height) / 2
        width: Math.max(childrenRect.width, 40)
        height: childrenRect.height
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Qt.alpha(Theme.line, 0.45)
    }
}
