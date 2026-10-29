import QtQuick
import qs.core
import qs.components

Column {
    id: root

    property string title: ""
    width: parent ? parent.width : 600
    spacing: 0

    Item {
        width: parent.width
        height: 44
        visible: root.title !== ""
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: root.title
            font.family: Tokens.fontSans
            font.pixelSize: 12
            font.weight: Font.Medium
            renderType: Text.NativeRendering
            color: Theme.glow
        }
    }
}
