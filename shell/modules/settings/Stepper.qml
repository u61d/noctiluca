import QtQuick
import qs.core

Item {
    id: root

    property int value: 0
    property int from: 0
    property int to: 10
    property string unit: ""
    property string zeroText: ""
    signal changed(int value)

    implicitWidth: 132
    implicitHeight: 26

    function nudge(d: int): void {
        const v = Math.max(root.from, Math.min(root.to, root.value + d));
        if (v !== root.value) root.changed(v);
    }

    component Sign: Text {
        id: s
        property int delta: 0
        font.family: Tokens.fontMono
        font.pixelSize: 15
        renderType: Text.NativeRendering
        color: sh.hovered ? Theme.glow : Theme.mute
        width: 22
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: s.parent.parent.nudge(s.delta) }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Sign { text: "−"; delta: -1 }
        Text {
            width: 72
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            text: root.value === 0 && root.zeroText !== "" ? root.zeroText : root.value + root.unit
            font.family: Tokens.fontMono
            font.pixelSize: 13
            renderType: Text.NativeRendering
            color: Theme.text
        }
        Sign { text: "+"; delta: 1 }
    }

    WheelHandler {
        onWheel: function(e) { root.nudge(e.angleDelta.y > 0 ? 1 : -1); }
    }
}
