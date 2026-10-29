import QtQuick
import qs.core

Item {
    id: root

    property real value: 0
    property real maximum: 1
    property string icon: ""
    property string text: Math.round(root.shown / root.maximum * 100) + "%"
    property bool off: false                 // muted: the band dims, the icon shows it
    property color accent: Theme.glow

    signal moved(real value)
    signal iconClicked()

    property bool dragging: false
    property real dragValue: 0
    readonly property real shown: root.dragging ? root.dragValue : root.value
    readonly property real fraction: Math.max(0, Math.min(1, root.shown / root.maximum))

    implicitHeight: 36
    opacity: root.enabled ? 1 : 0.45

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(1, 1, 1, hover.hovered ? 0.06 : 0.04)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
        clip: true

        Rectangle {
            id: band
            height: parent.height
            width: Math.max(parent.height, parent.width * root.fraction)
            radius: track.radius
            opacity: root.off ? 0.35 : 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.alpha(root.accent, 0.14) }
                GradientStop { position: 1.0; color: Qt.alpha(root.accent, 0.34) }
            }
            Behavior on width {
                enabled: !root.dragging
                NumberAnimation { duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                width: 2; height: parent.height - 16; radius: 1
                color: Theme.glowHi
                opacity: root.fraction > 0.04 ? (root.dragging || hover.hovered ? 1 : 0.7) : 0
            }
        }
    }

    Item {
        id: iconBox
        width: root.height; height: root.height
        Icon {
            anchors.centerIn: parent
            path: root.icon
            size: 17
            color: root.off ? Theme.mute : iconHover.hovered ? Theme.text : Theme.glowHi
        }
        HoverHandler { id: iconHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.iconClicked() }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        font.family: Tokens.fontMono; font.pixelSize: 11
        renderType: Text.NativeRendering
        color: root.off ? Theme.mute : Theme.dim
    }

    HoverHandler { id: hover }

    function at(x: real): real {
        // the icon's end counts as zero so the bottom is easy to hit
        const lo = root.height * 0.5, hi = root.width - root.height * 0.25;
        return Math.max(0, Math.min(1, (x - lo) / Math.max(1, hi - lo))) * root.maximum;
    }

    DragHandler {
        id: drag
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        dragThreshold: 2
        onActiveChanged: {
            if (drag.active) {
                root.dragValue = root.value;
                root.dragging = true;
            } else {
                root.moved(root.dragValue);
                root.dragging = false;
            }
        }
        onCentroidChanged: if (drag.active) {
            root.dragValue = root.at(drag.centroid.position.x);
            root.moved(root.dragValue);
        }
    }
    TapHandler {
        onTapped: function(point) {
            if (point.position.x > root.height) root.moved(root.at(point.position.x));
        }
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            root.moved(Math.max(0, Math.min(root.maximum, root.value + (event.angleDelta.y > 0 ? 0.05 : -0.05) * root.maximum)));
        }
    }
}
