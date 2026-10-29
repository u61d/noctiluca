import QtQuick
import qs.core

Column {
    id: root

    property date now: new Date()
    property string format: "hh:mm"
    property int size: 196
    property bool centred: false
    property real reveal: 1

    readonly property string timeText: Qt.formatDateTime(root.now, root.format)
    // so the date lines up with the first digit's stroke, not its box
    readonly property real inset: root.centred ? 0 : Math.round(root.size * 0.05)

    function part(from: real, span: real): real {
        return Math.max(0, Math.min(1, (root.reveal - from) / span));
    }

    spacing: -Math.round(root.size * 0.1)

    Text {
        anchors.horizontalCenter: root.centred ? parent.horizontalCenter : undefined
        leftPadding: root.inset
        text: Qt.formatDateTime(root.now, "dddd d MMMM")
        font.family: Tokens.fontSans; font.pixelSize: Math.round(root.size * 0.1); font.weight: Font.Light
        renderType: Text.NativeRendering
        color: Theme.dim
        opacity: root.part(0.0, 0.35)
        transform: Translate { y: 14 * (1 - root.part(0.0, 0.35)) }
    }

    Row {
        anchors.horizontalCenter: root.centred ? parent.horizontalCenter : undefined
        Repeater {
            model: root.timeText.length
            delegate: RollChar {
                required property int index
                ch: root.timeText.charAt(index)
                size: root.size
                weight: Font.Thin
                readonly property real inn: root.part(0.08 + index * 0.06, 0.4)
                opacity: inn
                transform: Translate { y: 40 * (1 - inn) }
            }
        }
    }
}
