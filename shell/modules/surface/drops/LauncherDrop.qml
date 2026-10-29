import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

// = sums, / files, ; emoji, # colours, : clipboard, > command
Item {
    id: root

    property var host: null

    implicitWidth: 620
    implicitHeight: col.implicitHeight

    function takeFocus(): void {
        field.input.forceActiveFocus();
    }

    readonly property var openWith: ({ clipboard: ":", emoji: ";", files: "/", colors: "#" })
    Component.onCompleted: {
        const p = root.openWith[Panels.launcherMode];
        if (p) {
            field.text = p;
            field.input.cursorPosition = 1;
        }
    }

    LauncherLogic {
        id: logic
        query: field.text
        openMode: Panels.launcherMode
        onRequestClose: Panels.close()
        onRequestClear: field.text = ""
    }

    readonly property var glyphs: ({ calc: "=", run: ">", clipboard: ":", files: "/", emoji: ";", colors: "#" })

    Column {
        id: col
        width: parent.width
        spacing: 0

        Item {
            width: parent.width; height: 44

            Text {
                id: modeGlyph
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                text: root.glyphs[logic.mode] || ""
                font.family: Tokens.fontMono; font.pixelSize: 20; font.weight: Font.Medium
                renderType: Text.NativeRendering
                color: Theme.glow
                visible: text !== ""
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                path: Icons.search
                size: 18
                color: Theme.mute
                visible: !modeGlyph.visible
            }
            Field {
                id: field
                anchors { left: parent.left; leftMargin: 34; right: parent.right; verticalCenter: parent.verticalCenter }
                placeholder: logic.placeholder
                rows: logic.grid
                onAccepted: logic.activate(logic.selected)
                onCancelled: Panels.close()
                onMoved: function(d) { logic.move(d); }
                onMovedRow: function(d) { logic.moveRow(d); }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.alpha(Theme.line, 0.6) }
        Item { width: 1; height: 8 }

        Grid {
            visible: logic.grid
            width: parent.width
            columns: logic.columns
            readonly property real cell: width / logic.columns
            Repeater {
                model: logic.grid ? logic.results : []
                delegate: Item {
                    id: em
                    required property var modelData
                    required property int index
                    readonly property bool isSel: em.index === logic.selected
                    width: parent.cell; height: 52
                    Rectangle {
                        anchors.centerIn: parent
                        width: 46; height: 46; radius: 12
                        color: em.isSel ? Qt.alpha(Theme.glow, 0.14) : emh.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                        border.width: em.isSel ? 1 : 0
                        border.color: Qt.alpha(Theme.glow, 0.45)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: em.modelData.emoji || ""
                        font.pixelSize: 26
                        font.family: "Noto Color Emoji"
                        scale: em.isSel || emh.hovered ? 1.12 : 1
                        Behavior on scale { NumberAnimation { duration: Motion.quick } }
                    }
                    HoverHandler { id: emh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: logic.activate(em.index) }
                }
            }
        }
        Text {
            visible: logic.grid && logic.results.length > 0
            width: parent.width
            topPadding: 6
            text: logic.results[logic.selected] ? logic.results[logic.selected].title : ""
            font.family: Tokens.fontMono; font.pixelSize: 11
            renderType: Text.NativeRendering
            color: Theme.dim
        }

        Repeater {
            model: logic.grid ? [] : logic.results

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool isSel: row.index === logic.selected
                readonly property bool big: row.modelData.kind === "calc" || !!row.modelData.image

                width: col.width
                height: row.big ? 64 : 46

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -10; anchors.rightMargin: -10
                    radius: Tokens.radiusField
                    color: row.isSel ? Qt.rgba(1, 1, 1, 0.07) : rh.hovered ? Qt.rgba(1, 1, 1, 0.035) : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.quick } }
                }

                Item {
                    id: ico
                    x: 4
                    width: row.big ? 48 : 28; height: width
                    anchors.verticalCenter: parent.verticalCenter

                    readonly property string themed: row.modelData.iconName ? Quickshell.iconPath(row.modelData.iconName, true) : ""

                    IconImage {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: ico.themed
                        visible: ico.themed !== "" && !row.modelData.image
                        asynchronous: true
                    }
                    Item {
                        anchors.fill: parent
                        visible: !!row.modelData.image
                        Image {
                            id: thumb
                            anchors.fill: parent
                            source: row.modelData.image || ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 96; sourceSize.height: 96
                            asynchronous: true
                            cache: false
                            visible: false
                        }
                        Rectangle {
                            anchors.fill: parent; radius: 8
                            color: Theme.surfaceSlate
                            visible: thumb.status !== Image.Ready
                            Icon { anchors.centerIn: parent; path: Icons.image; size: 18; color: Theme.mute }
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: thumb
                            visible: thumb.status === Image.Ready
                            maskEnabled: true
                            maskSource: thumbMask
                        }
                        Item {
                            id: thumbMask
                            anchors.fill: parent
                            layer.enabled: true
                            visible: false
                            Rectangle { anchors.fill: parent; radius: 8; color: "black" }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        visible: !!row.modelData.swatch
                        radius: 8
                        color: row.modelData.swatch || "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        visible: ico.themed === "" && !row.modelData.image && !row.modelData.swatch && !!row.modelData.icon
                        color: "transparent"
                        Icon {
                            anchors.centerIn: parent
                            path: row.modelData.icon || ""
                            size: row.big ? 20 : 15
                            color: row.isSel ? Theme.glowHi : Theme.dim
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: ico.themed === "" && !row.modelData.icon && !!row.modelData.glyph
                        text: row.modelData.glyph || ""
                        font.family: Tokens.fontMono; font.pixelSize: 22; font.weight: Font.Medium
                        renderType: Text.NativeRendering
                        color: row.isSel ? Theme.glow : Theme.mute
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radiusChip + 2
                        visible: ico.themed === "" && !row.modelData.image && !row.modelData.swatch && !row.modelData.icon && !row.modelData.glyph
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        Text {
                            anchors.centerIn: parent
                            text: (row.modelData.title || "?").charAt(0).toUpperCase()
                            font.family: Tokens.fontMono; font.pixelSize: 13; font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            color: Theme.dim
                        }
                    }
                }

                Column {
                    anchors { left: ico.right; leftMargin: 14; right: kindLabel.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 1
                    Text {
                        width: parent.width
                        text: row.modelData.title
                        elide: Text.ElideRight
                        font.family: Tokens.fontSans
                        font.pixelSize: row.modelData.kind === "calc" ? 26 : 14
                        font.weight: row.modelData.kind === "calc" ? Font.Light : Font.Medium
                        renderType: Text.NativeRendering
                        color: row.isSel ? Theme.text : Theme.dim
                    }
                    Text {
                        width: parent.width
                        text: row.modelData.subtitle || ""
                        visible: text !== ""
                        elide: Text.ElideMiddle
                        font.family: Tokens.fontSans; font.pixelSize: 12
                        renderType: Text.NativeRendering
                        color: row.modelData.subtitle === "recent" ? Qt.alpha(Theme.glow, 0.7) : Theme.mute
                    }
                }
                Text {
                    id: kindLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: ({ window: "window", setting: "setting", calc: logic.mode === "apps" ? "answer" : "" })[row.modelData.kind] || ""
                    font.family: Tokens.fontMono; font.pixelSize: 10; font.letterSpacing: 1
                    renderType: Text.NativeRendering
                    color: Theme.mute
                }

                // staggered, but capped so a full list isn't slow
                opacity: 0
                transform: Translate { id: arrive; y: 6 }
                Component.onCompleted: enter.start()
                SequentialAnimation {
                    id: enter
                    PauseAnimation { duration: Motion.stagger(row.index) }
                    ParallelAnimation {
                        NumberAnimation { target: row; property: "opacity"; to: 1; duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
                        NumberAnimation { target: arrive; property: "y"; to: 0; duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
                    }
                }

                HoverHandler { id: rh }
                TapHandler { onTapped: logic.activate(row.index) }
            }
        }

        Text {
            width: parent.width
            topPadding: 10; bottomPadding: 10
            visible: logic.results.length === 0 && logic.emptyText !== ""
            text: logic.emptyText
            font.family: Tokens.fontMono; font.pixelSize: 11
            renderType: Text.NativeRendering
            color: Theme.mute
        }

    }
}
