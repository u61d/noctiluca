import QtQuick
import qs.core

Item {
    id: root

    property real value: 0
    property real maximum: 1
    property color accent: Theme.glow
    // don't redeclare `enabled`, shadowing Item's stops it disabling the handlers

    signal moved(real value)

    property bool dragging: false
    property real dragValue: 0
    readonly property real shown: root.dragging ? root.dragValue : root.value

    implicitHeight: 16
    opacity: root.enabled ? 1 : 0.4

    Rectangle {
        id: rail
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 2
        radius: 1
        color: Qt.alpha(Theme.line, 0.9)
    }

    Filament {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: rail.width * Math.min(1, root.shown / root.maximum)
        spread: 3
        color: root.accent
        visible: this.width > 1
    }

    Node {
        anchors.verticalCenter: parent.verticalCenter
        x: rail.width * Math.min(1, root.shown / root.maximum) - width / 2
        core: root.dragging || hover.hovered ? 6 : 4
        halo: root.dragging || hover.hovered ? 5 : 3
        color: root.accent

        Behavior on core { NumberAnimation { duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }
        Behavior on halo { NumberAnimation { duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }
    }

    HoverHandler { id: hover }

    DragHandler {
        id: drag
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onActiveChanged: {
            if (drag.active) {
                root.dragging = true;
            } else {
                root.moved(root.dragValue);
                root.dragging = false;
            }
        }
        onCentroidChanged: if (drag.active) {
            root.dragValue = Math.min(root.maximum, Math.max(0,
                drag.centroid.position.x / Math.max(1, rail.width) * root.maximum));
            root.moved(root.dragValue);
        }
    }

    TapHandler {
        onTapped: function(point) {
            root.moved(Math.min(root.maximum, Math.max(0,
                point.position.x / Math.max(1, rail.width) * root.maximum)));
        }
    }
}
