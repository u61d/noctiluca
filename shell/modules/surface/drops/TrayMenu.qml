import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

Column {
    id: m
    property var handle: null
    property int depth: 0
    property int openIndex: -1

    QsMenuOpener { id: opener; menu: m.handle }

    Repeater {
        model: opener.children ? opener.children.values : []
        delegate: Column {
            id: entryCol
            required property var modelData
            required property int index
            readonly property bool expanded: m.openIndex === entryCol.index
            width: m.width

            Rectangle {
                visible: entryCol.modelData.isSeparator
                x: 10; width: parent.width - 20; height: 9
                color: "transparent"
                Rectangle { anchors.centerIn: parent; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
            }

            Item {
                visible: !entryCol.modelData.isSeparator
                width: parent.width
                height: 32
                opacity: entryCol.modelData.enabled ? 1 : 0.4

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: eh.hovered && entryCol.modelData.enabled ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                }
                Item {
                    id: lead
                    x: 10 + m.depth * 14
                    width: 18; height: parent.height
                    Icon {
                        anchors.centerIn: parent
                        visible: entryCol.modelData.buttonType === QsMenuButtonType.CheckBox && entryCol.modelData.checkState === Qt.Checked
                        path: Icons.check
                        size: 14
                        color: Theme.glowHi
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        visible: entryCol.modelData.buttonType === QsMenuButtonType.RadioButton
                        width: 12; height: 12; radius: 6
                        color: "transparent"
                        border.width: 1
                        border.color: entryCol.modelData.checkState === Qt.Checked ? Theme.glowHi : Theme.mute
                        Rectangle {
                            anchors.centerIn: parent
                            visible: entryCol.modelData.checkState === Qt.Checked
                            width: 6; height: 6; radius: 3
                            color: Theme.glowHi
                        }
                    }
                    IconImage {
                        anchors.centerIn: parent
                        visible: entryCol.modelData.buttonType === QsMenuButtonType.None && entryCol.modelData.icon !== ""
                        width: 16; height: 16
                        source: entryCol.modelData.icon
                        asynchronous: true
                    }
                }
                Text {
                    x: lead.x + lead.width + 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 30
                    // strip the accelerator underscores
                    text: (entryCol.modelData.text || "").replace(/_(?!_)/g, "").replace(/__/g, "_")
                    elide: Text.ElideRight
                    font.family: Tokens.fontSans; font.pixelSize: 13
                    renderType: Text.NativeRendering
                    color: Theme.text
                }
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: entryCol.modelData.hasChildren
                    path: entryCol.expanded ? Icons.chevronDown : Icons.chevronRight
                    size: 14
                    color: Theme.mute
                }
                HoverHandler { id: eh; cursorShape: entryCol.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler {
                    enabled: entryCol.modelData.enabled
                    onTapped: {
                        if (entryCol.modelData.hasChildren) {
                            m.openIndex = entryCol.expanded ? -1 : entryCol.index;
                            return;
                        }
                        entryCol.modelData.triggered();
                        Panels.close();
                    }
                }
            }

            // a file can't contain itself, so load the submenu by name
            Loader {
                width: parent.width
                active: entryCol.expanded
                visible: active
                source: Qt.resolvedUrl("TrayMenu.qml")
                onLoaded: {
                    item.width = Qt.binding(function() { return entryCol.width; });
                    item.depth = m.depth + 1;
                    item.handle = entryCol.modelData;
                }
            }
        }
    }
}
