import QtQuick
import qs.core
import qs.components
import qs.services

Rectangle {
    id: root

    color: Theme.surfaceDusk
    radius: 10
    clip: true

    Image {
        anchors.fill: parent
        source: Wallpapers.shown !== "" ? Paths.fileUrl(Wallpapers.shown) : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 1200
        asynchronous: true
        opacity: 0.85
    }

    property bool out: false
    readonly property real sheetW: 300
    readonly property real sheetH: 150
    readonly property real rise: 22

    Spring {
        id: p
        kind: root.out ? "open" : "close"
        target: root.out ? 1 : 0
        epsilon: 0.0008
    }

    readonly property real sheetTop: -root.rise - (1 - p.value) * root.sheetH
    readonly property real speed: Math.abs(p.velocity * root.sheetH)

    Waterline {
        id: water
        anchors.fill: parent
        light: Settings.appearance.light
        pool0: Qt.vector4d(-60, 150, 34, 16)
        pool2: Qt.vector4d(root.width - 190, root.width + 60, 34, 16)
        drop0: Qt.vector4d(root.width - 24 - root.sheetW, root.sheetTop, root.sheetW, root.sheetH)
        bend0: Qt.vector4d(Math.min(18, root.speed * 0.0055 * Motion.stretch),
                           Math.min(9, root.speed * 0.0022 * Motion.stretch), 0, 0)
        cursor: hov.hovered ? hov.point.position : Qt.point(-1, -1)
        HoverHandler { id: hov }
    }

    Item {
        x: root.width - 24 - root.sheetW + 22
        y: 34
        width: root.sheetW - 44
        height: root.height - 34
        clip: true
        Column {
            y: root.sheetTop + root.rise + 22 - 34 + 8
            spacing: 9
            opacity: Math.max(0, Math.min(1, (p.value - 0.12) / 0.55))
            Repeater {
                model: [0.55, 0.9, 0.7, 0.4]
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: (root.sheetW - 44) * modelData
                    height: index === 0 ? 8 : 5
                    radius: 2
                    color: index === 0 ? Theme.text : Qt.alpha(Theme.dim, 0.5)
                }
            }
        }
    }

    Text {
        x: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        text: root.out ? "click to close" : "click to open"
        font.family: Tokens.fontMono
        font.pixelSize: 11
        renderType: Text.NativeRendering
        color: Theme.mute
    }

    TapHandler { onTapped: root.out = !root.out }

    // replay once the slider has stopped for a moment
    Timer {
        id: replay
        interval: 260
        onTriggered: root.out = !root.out
    }
    Connections {
        target: Settings.motion
        function onSpeedChanged() { replay.restart(); }
        function onBounceChanged() { replay.restart(); }
        function onStretchChanged() { replay.restart(); }
    }
    Component.onCompleted: root.out = true
}
