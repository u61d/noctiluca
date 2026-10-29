import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray as Sni
import qs.core
import qs.components
import qs.services

Item {
    id: root

    property var host: null
    readonly property var item: Panels.trayItem

    implicitWidth: 300
    implicitHeight: col.implicitHeight

    readonly property bool stillThere: Sni.SystemTray.items.values.indexOf(root.item) >= 0
    onStillThereChanged: if (!root.stillThere) Panels.close()

    Column {
        id: col
        width: parent.width
        spacing: 2

        Item {
            width: parent.width; height: 36
            IconImage {
                id: head
                width: 20; height: 20
                anchors.verticalCenter: parent.verticalCenter
                source: root.item ? root.item.icon : ""
                asynchronous: true
            }
            Text {
                x: 32
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 32
                text: root.item ? (root.item.tooltipTitle || root.item.title || root.item.id) : ""
                elide: Text.ElideRight
                font.family: Tokens.fontSans; font.pixelSize: 14; font.weight: Font.Medium
                renderType: Text.NativeRendering
                color: Theme.text
            }
        }
        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
        Item { width: 1; height: 4 }

        TrayMenu {
            width: parent.width
            handle: root.item && root.item.hasMenu ? root.item.menu : null
            depth: 0
        }

        Text {
            visible: !root.item || !root.item.hasMenu
            topPadding: 6
            text: "This app has no menu."
            font.family: Tokens.fontSans; font.pixelSize: 13
            renderType: Text.NativeRendering
            color: Theme.dim
        }
    }
}
