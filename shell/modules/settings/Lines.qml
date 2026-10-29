import QtQuick
import qs.core
import qs.components

Item {
    id: root

    property var value: []
    signal committed(var list)

    implicitWidth: 340
    implicitHeight: Math.max(64, edit.contentHeight + 20)

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radiusField
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: edit.activeFocus ? Qt.alpha(Theme.glow, 0.5) : Qt.rgba(1, 1, 1, 0.07)
    }
    TextEdit {
        id: edit
        x: 12; y: 10
        width: parent.width - 24
        wrapMode: TextEdit.NoWrap
        font.family: Tokens.fontMono; font.pixelSize: 12
        color: Theme.text
        selectionColor: Qt.alpha(Theme.glow, 0.4)
        clip: true
        Component.onCompleted: edit.text = (root.value || []).join("\n")
        onActiveFocusChanged: if (!activeFocus) {
            const list = edit.text.split("\n").map(function(s) { return s.trim(); }).filter(function(s) { return s !== ""; });
            if (JSON.stringify(list) !== JSON.stringify(root.value || [])) root.committed(list);
        }
        Text {
            visible: edit.text === "" && !edit.activeFocus
            text: "~/calendar.ics\nhttps://…/basic.ics"
            font: edit.font
            color: Theme.mute
        }
    }
}
