import QtQuick
import qs.core

// keys are handled by the screen, not here, so nothing can be selected or copied
Item {
    id: root

    property int length: 0
    property bool busy: false
    property bool failed: false
    property bool capsLock: false
    property string placeholder: "Password"
    readonly property int maxBeads: 24

    signal accepted()

    implicitWidth: 320
    implicitHeight: 44

    readonly property color tint: root.failed ? Theme.alert : Theme.glow
    readonly property real lineY: root.height - 6
    readonly property real beadsX: Math.min(beads.width, root.width) / 2 + 4
    readonly property real beadsY: beads.y + beads.height / 2

    Text {
        anchors.left: parent.left
        anchors.baseline: parent.top
        anchors.baselineOffset: root.lineY - 12
        visible: root.length === 0 && !root.busy
        text: root.placeholder
        font.family: Tokens.fontSans; font.pixelSize: 15
        renderType: Text.NativeRendering
        color: Theme.mute
    }

    Row {
        id: beads
        x: 1
        y: root.lineY - 12 - height
        spacing: 3
        Repeater {
            model: Math.min(root.length, root.maxBeads)
            delegate: Node {
                id: bead
                required property int index
                core: 6; halo: 3
                color: root.failed ? Theme.alert : Theme.glowHi
                intensity: root.busy ? 0.3 + 0.7 * Math.max(0, Math.sin((wave.t - bead.index / Math.max(1, root.length)) * Math.PI * 2)) : 1
                scale: 0
                transform: Translate { id: lift; y: 6 }
                Component.onCompleted: arrive.start()
                ParallelAnimation {
                    id: arrive
                    NumberAnimation { target: bead; property: "scale"; from: 0; to: 1; duration: Motion.base; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                    NumberAnimation { target: lift; property: "y"; from: 6; to: 0; duration: Motion.base; easing.type: Easing.OutCubic }
                }
            }
        }
    }
    QtObject { id: wave; property real t: 0 }
    NumberAnimation {
        target: wave; property: "t"; from: 0; to: 1
        duration: 900; loops: Animation.Infinite
        running: root.busy && root.visible
    }

    Rectangle {
        y: root.lineY
        width: root.width; height: 1
        color: root.failed ? Qt.alpha(Theme.alert, 0.5) : Qt.alpha(Theme.text, 0.22)
        Behavior on color { ColorAnimation { duration: Motion.base } }
    }
    Filament {
        x: 0
        y: root.lineY - height / 2 + 0.5
        width: root.length > 0 || root.busy ? Math.min(root.width, beads.width + 10) : 0
        spread: 3
        color: root.tint
        intensity: root.length > 0 || root.busy ? 1 : 0
        Behavior on width { NumberAnimation { duration: Motion.quick; easing.type: Easing.OutCubic } }
    }

    Text {
        anchors.right: parent.right
        anchors.baseline: parent.top
        anchors.baselineOffset: root.lineY - 12
        visible: root.capsLock
        text: "Caps Lock"
        font.family: Tokens.fontSans; font.pixelSize: 12
        renderType: Text.NativeRendering
        color: Theme.alert
    }
    Icon {
        id: go
        visible: !root.capsLock
        anchors.right: parent.right
        y: root.lineY - 12 - height + 3
        path: Icons.chevronRight
        size: 18
        readonly property bool live: root.length > 0 && !root.busy
        color: go.live ? (goHover.hovered ? Theme.glowHi : Theme.dim) : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.quick } }
        HoverHandler { id: goHover; cursorShape: go.live ? Qt.PointingHandCursor : Qt.ArrowCursor; margin: 8 }
        TapHandler { onTapped: if (go.live) root.accepted() }
    }
}
