import QtQuick
import qs.core

Item {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property color accent: Theme.glow

    signal accepted()
    signal cancelled()
    signal moved(int delta)
    property bool rows: false
    signal movedRow(int delta)

    implicitHeight: input.implicitHeight + Tokens.s4

    TextInput {
        id: input
        anchors { left: parent.left; right: parent.right; top: parent.top }
        color: Theme.text
        font.family: Tokens.fontSans
        font.pixelSize: Tokens.typeTitle.pixelSize
        font.weight: Tokens.typeTitle.weight
        selectByMouse: true
        selectionColor: Qt.alpha(root.accent, 0.3)
        selectedTextColor: Theme.text
        focus: true

        onAccepted: root.accepted()
        Keys.onEscapePressed: root.cancelled()
        Keys.onDownPressed: root.rows ? root.movedRow(1) : root.moved(1)
        Keys.onUpPressed: root.rows ? root.movedRow(-1) : root.moved(-1)
        Keys.onTabPressed: root.moved(1)
        Keys.onBacktabPressed: root.moved(-1)
    }

    Text {
        anchors.fill: input
        visible: input.text === ""
        text: root.placeholder
        color: Theme.mute
        font: input.font
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.line
    }

    Rectangle {
        anchors { left: parent.left; bottom: parent.bottom }
        width: input.activeFocus ? parent.width : 0
        height: 1
        color: root.accent

        Behavior on width {
            NumberAnimation { duration: Motion.smooth; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.glide }
        }
    }
}
