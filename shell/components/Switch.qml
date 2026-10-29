import QtQuick
import qs.core

Item {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 46
    implicitHeight: 26
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
        color: Qt.tint(Qt.rgba(1, 1, 1, 0.06), Qt.alpha(Theme.glow, 0.32 * knob.value))
        border.width: 1
        border.color: Qt.tint(Qt.rgba(1, 1, 1, 0.08), Qt.alpha(Theme.glow, 0.7 * knob.value))
    }
    Rectangle {
        width: 18; height: 18; radius: 9
        anchors.verticalCenter: parent.verticalCenter
        x: 4 + knob.value * (root.width - 26)
        color: Qt.tint(Theme.mute, Qt.alpha(Theme.glowHi, knob.value))
        scale: hover.hovered ? 1.08 : 1
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
