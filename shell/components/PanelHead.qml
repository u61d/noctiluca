import QtQuick
import qs.core

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string note: ""
    property bool on: false
    property bool busy: false            // scanning
    property bool hasSwitch: true
    signal toggled(bool on)

    implicitHeight: 48

    Icon {
        id: disc
        anchors.verticalCenter: parent.verticalCenter
        path: root.icon
        size: 22
        color: root.on ? Theme.glowHi : Theme.mute
        opacity: root.busy && root.on ? 0.55 + 0.45 * breath.v : 1
        Behavior on color { ColorAnimation { duration: Motion.base } }
        QtObject { id: breath; property real v: 1 }
        SequentialAnimation {
            running: root.busy && root.on && root.visible
            loops: Animation.Infinite
            onRunningChanged: if (!running) breath.v = 1
            NumberAnimation { target: breath; property: "v"; to: 0; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { target: breath; property: "v"; to: 1; duration: 900; easing.type: Easing.InOutSine }
        }
    }

    Column {
        anchors { left: disc.right; leftMargin: 16; right: sw.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 3
        Text {
            width: parent.width
            text: root.title
            elide: Text.ElideRight
            font.family: Tokens.fontSans; font.pixelSize: 17; font.weight: Font.Medium
            renderType: Text.NativeRendering
            color: Theme.text
        }
        Text {
            width: parent.width
            text: root.note
            elide: Text.ElideRight
            font.family: Tokens.fontSans; font.pixelSize: 13
            renderType: Text.NativeRendering
            color: Theme.mute
        }
    }

    Switch {
        id: sw
        visible: root.hasSwitch
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        checked: root.on
        onToggled: function(c) { root.toggled(c); }
    }
}
