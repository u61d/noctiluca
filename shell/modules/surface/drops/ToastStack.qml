import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.core
import qs.components
import qs.services

// Notifs.popups gets replaced on every change, so mirror it into a ListModel keyed by uid,
// otherwise every toast rebuilds (and restarts its timer) when a new one arrives
Item {
    id: root

    property var host: null
    readonly property int count: rows.count

    implicitWidth: 380
    implicitHeight: list.contentHeight

    property var byUid: ({})

    ListModel { id: rows }

    function sync(): void {
        const want = Notifs.popups.map(function(e) { return Notifs.stamp(e); });
        const ids = want.map(function(e) { return e.uid; });
        for (const e of want) root.byUid[e.uid] = e;
        for (let i = rows.count - 1; i >= 0; i--)
            if (ids.indexOf(rows.get(i).uid) < 0) rows.remove(i);
        for (let i = 0; i < ids.length; i++) {
            if (i < rows.count && rows.get(i).uid === ids[i]) continue;
            let found = -1;
            for (let k = i + 1; k < rows.count; k++)
                if (rows.get(k).uid === ids[i]) { found = k; break; }
            if (found >= 0) rows.move(found, i, 1);
            else rows.insert(i, { uid: ids[i] });
        }
    }

    Connections {
        target: Notifs
        function onPopupsChanged() { root.sync(); }
    }
    Component.onCompleted: root.sync()

    ListView {
        id: list
        width: parent.width
        height: list.contentHeight
        interactive: false
        model: rows

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
            NumberAnimation { property: "x"; from: 24; to: 0; duration: Motion.smooth; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.exit }
            NumberAnimation { property: "x"; to: 24; duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.exit }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: Motion.smooth; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
            NumberAnimation { property: "opacity"; to: 1; duration: Motion.quick }
        }

        delegate: Item {
            id: toast
            required property int uid
            required property int index
            readonly property var entry: root.byUid[toast.uid] || ({})
            // the live object while the sender keeps it open, so replacements show
            readonly property var live: toast.entry.notification || toast.entry

            readonly property bool critical: toast.entry.urgency === NotificationUrgency.Critical
            readonly property color accent: toast.critical ? Theme.alert : Theme.glow
            readonly property int lifetime: Notifs.lifetime(toast.entry)
            property real remaining: 1
            property bool typing: false

            width: list.width
            height: body.implicitHeight + 26

            Rectangle {
                visible: toast.index > 0
                width: parent.width; height: 1
                color: Qt.alpha(Theme.line, 0.6)
            }

            Column {
                id: body
                x: 0; y: 13
                width: parent.width
                spacing: 6

                Item {
                    width: parent.width; height: 16
                    IconImage {
                        id: appIcon
                        width: 15; height: 15
                        anchors.verticalCenter: parent.verticalCenter
                        source: Notifs.appIconOf(toast.entry)
                        visible: source != ""
                        asynchronous: true
                    }
                    Icon {
                        visible: !appIcon.visible && !!toast.entry.glyph
                        anchors.verticalCenter: parent.verticalCenter
                        path: toast.entry.glyph || ""
                        size: 14
                        color: toast.accent
                    }
                    Text {
                        x: appIcon.visible || !!toast.entry.glyph ? 22 : 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: toast.live.appName || "Notification"
                        font.family: Tokens.fontSans
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                        color: toast.accent
                    }
                    Icon {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        path: Icons.close
                        size: 14
                        color: closeHover.hovered ? Theme.text : Theme.mute
                        HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Notifs.dismissPopup(toast.entry) }
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(texts.implicitHeight, pic.visible ? pic.height : 0)

                    Column {
                        id: texts
                        width: parent.width - (pic.visible ? pic.width + 14 : 0)
                        spacing: 2
                        TypeText {
                            width: parent.width
                            role: "title"
                            color: Theme.text
                            text: toast.live.summary || ""
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }
                        TypeText {
                            width: parent.width
                            role: "body"
                            color: Theme.dim
                            text: toast.live.body || ""
                            visible: text !== ""
                            elide: Text.ElideRight
                            maximumLineCount: 3
                            wrapMode: Text.Wrap
                            textFormat: Text.StyledText
                        }
                    }

                    Rectangle {
                        id: pic
                        anchors.right: parent.right
                        readonly property string src: Notifs.imageOf(toast.entry)
                        visible: (src !== "" && art.status !== Image.Error) || !!toast.entry.swatch
                        width: 52; height: 52; radius: 10
                        color: toast.entry.swatch ? toast.entry.swatch : Theme.surfaceSlate
                        border.width: toast.entry.swatch ? 1 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        Image {
                            id: art
                            anchors.fill: parent
                            source: pic.src
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 104; sourceSize.height: 104
                            asynchronous: true
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: art
                            visible: pic.src !== "" && art.status === Image.Ready
                            maskEnabled: true
                            maskSource: artMask
                        }
                        Item {
                            id: artMask
                            anchors.fill: parent
                            layer.enabled: true
                            visible: false
                            Rectangle { anchors.fill: parent; radius: 10; color: "black" }
                        }
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 6
                    visible: !!toast.live.actions && toast.live.actions.length > 0
                    Repeater {
                        model: toast.live.actions || []
                        delegate: Rectangle {
                            id: act
                            required property var modelData
                            width: actText.implicitWidth + 22; height: 26; radius: 13
                            color: ah.hovered ? Qt.alpha(toast.accent, 0.22) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: ah.hovered ? Qt.alpha(toast.accent, 0.5) : Qt.rgba(1, 1, 1, 0.07)
                            Text {
                                id: actText
                                anchors.centerIn: parent
                                text: act.modelData.text
                                font.family: Tokens.fontSans
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                renderType: Text.NativeRendering
                                color: ah.hovered ? Theme.text : Theme.dim
                            }
                            HoverHandler { id: ah; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: { act.modelData.invoke(); Notifs.dismissPopup(toast.entry); } }
                        }
                    }
                }

                Rectangle {
                    visible: !!toast.entry.notification && toast.entry.notification.hasInlineReply === true
                    width: parent.width; height: 32; radius: 16
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: reply.activeFocus ? Qt.alpha(toast.accent, 0.55) : Qt.rgba(1, 1, 1, 0.07)
                    TextInput {
                        id: reply
                        x: 14; width: parent.width - 48
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Tokens.fontSans; font.pixelSize: 12
                        color: Theme.text
                        selectionColor: Qt.alpha(Theme.glow, 0.4)
                        clip: true
                        onActiveFocusChanged: toast.typing = activeFocus
                        onAccepted: { Notifs.reply(toast.entry, text); Notifs.dismissPopup(toast.entry); }
                        Text {
                            visible: reply.text === "" && !reply.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                            text: (toast.entry.notification && toast.entry.notification.inlineReplyPlaceholder) || "Reply"
                            font: reply.font
                            color: Theme.mute
                        }
                    }
                    Icon {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        path: Icons.send
                        size: 14
                        color: reply.text !== "" ? Theme.glowHi : Theme.mute
                        TapHandler { onTapped: { Notifs.reply(toast.entry, reply.text); Notifs.dismissPopup(toast.entry); } }
                    }
                }
            }

            Rectangle {
                x: 0; y: parent.height - 3
                width: parent.width * toast.remaining
                height: 1
                color: Theme.mute
                opacity: 0.35
                visible: !toast.critical && toast.lifetime > 0
            }

            NumberAnimation {
                target: toast; property: "remaining"; from: 1; to: 0
                duration: toast.lifetime
                running: !toast.critical && toast.lifetime > 0
                paused: running && (hoverToast.hovered || toast.typing || (root.host !== null && !root.host.toastsShowing))
                onFinished: Notifs.dismissPopup(toast.entry)
            }

            HoverHandler { id: hoverToast }
            TapHandler {
                onTapped: function(point) {
                    if (root.host && root.host.pulseAt) {
                        const p = toast.mapToItem(null, point.position.x, point.position.y);
                        root.host.pulseAt(p.x, p.y, 0.9);
                    }
                    Notifs.dismissPopup(toast.entry);
                }
            }
        }
    }
}
