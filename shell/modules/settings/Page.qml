import QtQuick
import qs.core
import qs.components

Column {
    id: root

    property string title: ""
    property string intro: ""

    width: parent ? parent.width : 700
    spacing: 18

    Column {
        width: parent.width
        spacing: 6
        Text {
            text: root.title
            font.family: Tokens.fontSans
            font.pixelSize: 30
            font.weight: Font.Light
            renderType: Text.NativeRendering
            color: Theme.text
        }
        Text {
            width: parent.width
            text: root.intro
            visible: text !== ""
            wrapMode: Text.Wrap
            font.family: Tokens.fontSans
            font.pixelSize: 13
            renderType: Text.NativeRendering
            color: Theme.dim
            lineHeight: 1.25
        }
    }
}
