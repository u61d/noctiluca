import QtQuick
import qs.core
import qs.components
import qs.services

// seeks on release so the player's own position updates don't fight the drag
Item {
    id: root

    property color accent: Players.accent
    property bool dragging: false
    property real dragFraction: 0

    readonly property real shownFraction: root.dragging ? root.dragFraction : Players.progress

    implicitHeight: 18

    Rectangle {
        id: rail
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 1
        color: Theme.line
    }

    Rectangle {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: rail.width * root.shownFraction
        height: 1
        color: root.accent
    }

    Node {
        anchors.verticalCenter: parent.verticalCenter
        x: rail.width * root.shownFraction - width / 2
        core: root.dragging || hover.hovered ? 6 : 4
        halo: root.dragging || hover.hovered ? 5 : 3
        color: root.accent

        Behavior on core { NumberAnimation { duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }
        Behavior on halo { NumberAnimation { duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }
    }

    HoverHandler { id: hover; enabled: Players.canSeek }

    DragHandler {
        id: drag
        enabled: Players.canSeek
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onActiveChanged: {
            if (drag.active) {
                root.dragging = true;
            } else {
                Players.seekFraction(root.dragFraction);
                root.dragging = false;
            }
        }
        onCentroidChanged: if (drag.active)
            root.dragFraction = Math.min(1, Math.max(0, drag.centroid.position.x / Math.max(1, rail.width)))
    }

    TapHandler {
        enabled: Players.canSeek
        onTapped: function(point) {
            Players.seekFraction(Math.min(1, Math.max(0, point.position.x / Math.max(1, rail.width))));
        }
    }
}
