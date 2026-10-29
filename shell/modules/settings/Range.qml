import QtQuick
import qs.core
import qs.components

Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.01
    property string unit: ""
    property int decimals: 2
    property var format: null
    signal changed(real value)

    implicitWidth: 260
    implicitHeight: 24

    function snap(v: real): real {
        const s = Math.round((v - root.from) / root.step) * root.step + root.from;
        return Math.max(root.from, Math.min(root.to, Math.round(s * 1e6) / 1e6));
    }

    Slider {
        id: slider
        anchors { left: parent.left; right: label.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
        maximum: 1
        value: (root.value - root.from) / Math.max(1e-9, root.to - root.from)
        onMoved: function(v) {
            const next = root.snap(root.from + v * (root.to - root.from));
            if (next !== root.value) root.changed(next);
        }
    }

    Text {
        id: label
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 58
        horizontalAlignment: Text.AlignRight
        text: root.format ? root.format(root.value) : root.value.toFixed(root.decimals) + root.unit
        font.family: Tokens.fontMono
        font.pixelSize: 12
        renderType: Text.NativeRendering
        color: Theme.dim
    }
}
