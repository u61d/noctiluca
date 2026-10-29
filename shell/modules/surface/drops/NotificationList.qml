import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

Column {
    id: root

    property int maxGroups: 4
    property var open: ({})          // app -> expanded
    spacing: 8

    function toggle(app: string): void {
        const o = Object.assign({}, root.open);
        o[app] = !o[app];
        root.open = o;
    }

    Repeater {
        model: Notifs.groups.slice(0, root.maxGroups)

        delegate: Rectangle {
            id: group
            required property var modelData
            readonly property var items: group.modelData.items
            readonly property bool expanded: root.open[group.modelData.app] === true && group.items.length > 1

            width: root.width
            height: inner.implicitHeight + 24
            radius: Tokens.radiusField
            color: Qt.rgba(1, 1, 1, gh.hovered ? 0.05 : 0.035)
            Behavior on height { NumberAnimation { duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }
            clip: true
            HoverHandler { id: gh }

            Column {
                id: inner
                x: 14; y: 12
                width: parent.width - 28
                spacing: 10

                Item {
                    width: parent.width
                    height: 20

                    IconImage {
                        id: appIcon
                        width: 18; height: 18
                        anchors.verticalCenter: parent.verticalCenter
                        source: Notifs.appIconOf(group.items[0])
                        visible: source != ""
                        asynchronous: true
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !appIcon.visible
                        path: group.items[0].glyph || Icons.bell
                        size: 16
                        color: Theme.glow
                    }
                    Text {
                        x: 28
                        anchors.verticalCenter: parent.verticalCenter
                        text: group.modelData.app
                        font.family: Tokens.fontSans; font.pixelSize: 12; font.weight: Font.Medium
                        renderType: Text.NativeRendering
                        color: Theme.dim
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Rectangle {
                            visible: group.items.length > 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: countRow.implicitWidth + 14; height: 20; radius: 10
                            color: ch.hovered ? Qt.alpha(Theme.glow, 0.2) : Qt.alpha(Theme.glow, 0.1)
                            Row {
                                id: countRow
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: group.items.length
                                    font.family: Tokens.fontMono; font.pixelSize: 10
                                    renderType: Text.NativeRendering
                                    color: Theme.glowHi
                                }
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    path: group.expanded ? Icons.chevronUp : Icons.chevronDown
                                    size: 12
                                    color: Theme.glowHi
                                }
                            }
                            HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.toggle(group.modelData.app) }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: SystemStats.ago(group.items[0].time)
                            font.family: Tokens.fontMono; font.pixelSize: 10
                            renderType: Text.NativeRendering
                            color: Theme.mute
                        }
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            path: Icons.close
                            size: 14
                            color: xh.hovered ? Theme.text : Theme.mute
                            HoverHandler { id: xh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: group.items.length === 1 ? Notifs.dismiss(group.items[0]) : Notifs.dismissGroup(group.modelData.app) }
                        }
                    }
                }

                Repeater {
                    model: group.expanded ? group.items.slice(0, 6) : group.items.slice(0, 1)
                    delegate: Entry {
                        required property var modelData
                        required property int index
                        entry: modelData
                        width: inner.width
                        full: index === 0
                        separated: index > 0
                    }
                }
            }
        }
    }

    component Entry: Column {
        id: e
        property var entry: ({})
        property bool full: true
        property bool separated: false
        readonly property var live: e.entry.notification || e.entry
        readonly property string image: Notifs.imageOf(e.entry)
        spacing: 8

        Rectangle {
            visible: e.separated
            width: parent.width; height: 1
            color: Qt.rgba(1, 1, 1, 0.05)
        }

        Item {
            width: parent.width
            height: Math.max(texts.implicitHeight, pic.visible ? pic.height : 0)

            Column {
                id: texts
                width: parent.width - (pic.visible ? pic.width + 12 : 0) - (e.separated ? 22 : 0)
                spacing: 2
                Text {
                    width: parent.width
                    text: e.live.summary || ""
                    elide: Text.ElideRight
                    font.family: Tokens.fontSans; font.pixelSize: 13; font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    color: Theme.text
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: e.live.body || ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: e.full ? 3 : 1
                    elide: Text.ElideRight
                    font.family: Tokens.fontSans; font.pixelSize: 12
                    renderType: Text.NativeRendering
                    color: Theme.dim
                }
            }
            Rectangle {
                id: pic
                anchors.right: parent.right
                visible: e.image !== "" || !!e.entry.swatch
                width: 44; height: 44; radius: 8
                color: e.entry.swatch ? e.entry.swatch : Theme.surfaceSlate
                Image {
                    id: picImg
                    anchors.fill: parent
                    source: e.image
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 88; sourceSize.height: 88
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: picImg
                    visible: e.image !== "" && picImg.status === Image.Ready
                    maskEnabled: true
                    maskSource: picMask
                }
                Item {
                    id: picMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    Rectangle { anchors.fill: parent; radius: 8; color: "black" }
                }
            }
            Icon {
                visible: e.separated
                anchors.right: parent.right
                path: Icons.close
                size: 13
                color: dh.hovered ? Theme.text : Theme.mute
                HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Notifs.dismiss(e.entry) }
            }
        }

        Flow {
            width: parent.width
            spacing: 6
            visible: e.full && !!e.live.actions && e.live.actions.length > 0
            Repeater {
                model: e.full ? (e.live.actions || []) : []
                delegate: Rectangle {
                    required property var modelData
                    width: at.implicitWidth + 20; height: 26; radius: 13
                    color: ah.hovered ? Qt.alpha(Theme.glow, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: ah.hovered ? Qt.alpha(Theme.glow, 0.45) : Qt.rgba(1, 1, 1, 0.06)
                    Text {
                        id: at
                        anchors.centerIn: parent
                        text: parent.modelData.text
                        font.family: Tokens.fontSans; font.pixelSize: 12
                        renderType: Text.NativeRendering
                        color: ah.hovered ? Theme.text : Theme.dim
                    }
                    HoverHandler { id: ah; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { parent.modelData.invoke(); Notifs.dismiss(e.entry); } }
                }
            }
        }

        Rectangle {
            visible: e.full && !!e.entry.notification && e.entry.notification.hasInlineReply === true
            width: parent.width; height: 32; radius: 16
            color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            border.color: replyInput.activeFocus ? Qt.alpha(Theme.glow, 0.5) : Qt.rgba(1, 1, 1, 0.06)
            TextInput {
                id: replyInput
                x: 14; width: parent.width - 50
                anchors.verticalCenter: parent.verticalCenter
                font.family: Tokens.fontSans; font.pixelSize: 12
                color: Theme.text
                selectionColor: Qt.alpha(Theme.glow, 0.4)
                clip: true
                onAccepted: { Notifs.reply(e.entry, text); text = ""; }
                Text {
                    visible: replyInput.text === "" && !replyInput.activeFocus
                    anchors.verticalCenter: parent.verticalCenter
                    text: (e.entry.notification && e.entry.notification.inlineReplyPlaceholder) || "Reply"
                    font: replyInput.font
                    color: Theme.mute
                }
            }
            Icon {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                path: Icons.send
                size: 14
                color: replyInput.text !== "" ? Theme.glowHi : Theme.mute
                TapHandler { onTapped: { Notifs.reply(e.entry, replyInput.text); replyInput.text = ""; } }
            }
        }
    }
}
