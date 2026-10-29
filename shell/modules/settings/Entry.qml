import QtQuick
import qs.core
import qs.components

// applied on enter or blur, otherwise half-typed values (a layout, a city) get applied
Item {
    id: root

    property string value: ""
    property string placeholder: ""
    signal committed(string value)

    implicitWidth: 260
    implicitHeight: 30

    Field {
        id: field
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        placeholder: root.placeholder
        input.font.pixelSize: 13
        input.font.weight: Font.Normal
        input.focus: false
        Component.onCompleted: field.text = root.value
        onAccepted: root.committed(field.text)
        input.onActiveFocusChanged: if (!input.activeFocus && field.text !== root.value) root.committed(field.text)
    }

    Connections {
        target: root
        function onValueChanged() { if (!field.input.activeFocus) field.text = root.value; }
    }
}
