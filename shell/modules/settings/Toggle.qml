import QtQuick
import qs.core
import qs.components

Item {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 38
    implicitHeight: 20
    opacity: root.enabled ? 1 : 0.4

    Spring {
        id: knob
        kind: "nudge"
        target: root.checked ? 1 : 0
        epsilon: 0.002
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(Theme.glow, 0.16 * knob.value)
        border.width: 1
        border.color: Qt.tint(Theme.line, Qt.alpha(Theme.glow, 0.85 * knob.value))
    }

    Rectangle {
        width: 12; height: 12; radius: 6
        anchors.verticalCenter: parent.verticalCenter
        x: 4 + knob.value * (root.width - 20)
        color: Qt.tint(Theme.mute, Qt.alpha(Theme.glow, knob.value))
        scale: hover.hovered ? 1.12 : 1
        Behavior on scale { NumberAnimation { duration: Motion.quick } }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        onTapped: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
