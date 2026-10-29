import QtQuick
import Quickshell
import qs.core
import qs.components
import qs.services

FloatingWindow {
    id: win

    title: "NOCTILUCA Settings"
    implicitWidth: 920
    implicitHeight: 640
    minimumSize: Qt.size(520, 400)
    color: Theme.surfaceVoid

    onClosed: Panels.settingsOpen = false

    readonly property var pages: [
        { key: "look", label: "Look", file: "pages/LookPage.qml" },
        { key: "motion", label: "Motion", file: "pages/MotionPage.qml" },
        { key: "bar", label: "Bar", file: "pages/BarPage.qml" },
        { key: "notifications", label: "Notifications", file: "pages/NotificationsPage.qml" },
        { key: "desktop", label: "Desktop", file: "pages/DesktopPage.qml" },
        { key: "nightlight", label: "Night light", file: "pages/NightLightPage.qml" },
        { key: "panels", label: "Panels", file: "pages/PanelsPage.qml" },
        { key: "lock", label: "Lock & idle", file: "pages/LockPage.qml" },
        { key: "windows", label: "Windows", file: "pages/WindowsPage.qml" },
        { key: "input", label: "Input", file: "pages/InputPage.qml" },
        { key: "about", label: "About", file: "pages/AboutPage.qml" }
    ]
    property int page: Math.max(0, win.pages.findIndex(function(p) { return p.key === Panels.settingsPage; }))
    readonly property bool narrow: win.width < 760

    Item {
        anchors.fill: parent
        focus: true
        // escape doesn't close it, it belongs to whatever field you're in
        Keys.onPressed: function(e) {
            if (!(e.modifiers & Qt.ControlModifier)) return;
            if (e.key === Qt.Key_PageDown || e.key === Qt.Key_Tab) {
                win.page = (win.page + 1) % win.pages.length;
                e.accepted = true;
            } else if (e.key === Qt.Key_PageUp || e.key === Qt.Key_Backtab) {
                win.page = (win.page + win.pages.length - 1) % win.pages.length;
                e.accepted = true;
            }
        }

        Rectangle {
            id: rail
            width: win.narrow ? 64 : 236
            Behavior on width { NumberAnimation { duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }
            height: parent.height
            color: Theme.surfaceInk

            Column {
                x: 28
                y: 30
                spacing: 2
                visible: !win.narrow

                Text {
                    text: "noctiluca"
                    font.family: Tokens.fontSans
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    color: Theme.glow
                }
                Text {
                    text: "settings"
                    font.family: Tokens.fontSans
                    font.pixelSize: 22
                    font.weight: Font.Light
                    renderType: Text.NativeRendering
                    color: Theme.text
                }
            }

            Column {
                id: nav
                x: 0
                y: win.narrow ? 30 : 110
                width: parent.width

                Repeater {
                    model: win.pages
                    delegate: Item {
                        id: entry
                        required property var modelData
                        required property int index
                        readonly property bool current: entry.index === win.page
                        width: nav.width
                        height: 38

                        Text {
                            x: 24
                            visible: win.narrow
                            anchors.verticalCenter: parent.verticalCenter
                            text: (entry.index + 1 < 10 ? "0" : "") + (entry.index + 1)
                            font.family: Tokens.fontMono
                            font.pixelSize: 10
                            renderType: Text.NativeRendering
                            color: entry.current ? Theme.glow : Theme.mute
                        }
                        Text {
                            x: 28
                            visible: !win.narrow
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.label
                            font.family: Tokens.fontSans
                            font.pixelSize: 14
                            font.weight: entry.current ? Font.Medium : Font.Normal
                            renderType: Text.NativeRendering
                            color: entry.current ? Theme.text : navHover.hovered ? Theme.dim : Theme.mute
                            Behavior on color { ColorAnimation { duration: Motion.quick } }
                        }
                        HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: win.page = entry.index }
                    }
                }
            }

            Spring { id: markY; kind: "nudge"; target: nav.y + win.page * 38 + 11 }
            Filament {
                vertical: true
                x: -3
                y: markY.value
                height: 16
                spread: 3
            }

            Text {
                x: 28
                visible: !win.narrow
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26
                width: parent.width - 56
                text: "Changes apply as you make them."
                wrapMode: Text.Wrap
                font.family: Tokens.fontSans
                font.pixelSize: 11
                renderType: Text.NativeRendering
                color: Theme.mute
            }
        }

        Rectangle {
            x: rail.width
            width: 1
            height: parent.height
            color: Qt.alpha(Theme.line, 0.5)
        }

        Flickable {
            id: flick
            x: rail.width + 1
            width: parent.width - x
            height: parent.height
            contentWidth: width
            contentHeight: pageLoader.height + 120
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: pageLoader
                x: win.narrow ? 24 : 56
                y: win.narrow ? 28 : 46
                width: Math.min(760, flick.width - 2 * x)
                source: Qt.resolvedUrl(win.pages[win.page].file)
                onSourceChanged: flick.contentY = 0
                opacity: 0
                onLoaded: fadeIn.restart()
                NumberAnimation {
                    id: fadeIn
                    target: pageLoader; property: "opacity"; from: 0; to: 1
                    duration: Motion.base
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle
                }
            }
        }
    }
}
