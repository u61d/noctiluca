import QtQuick
import QtQuick.Shapes
import qs.core

Item {
    id: root

    property color color: Theme.glow
    property real intensity: 1.0
    property real spread: 4        // how far the light bleeds from the core line
    property bool vertical: false

    implicitWidth: root.vertical ? 1 + root.spread * 2 : 120
    implicitHeight: root.vertical ? 120 : 1 + root.spread * 2

    Shape {
        anchors.fill: parent
        asynchronous: false
        opacity: root.intensity * 0.5

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: root.vertical ? root.width : 0
                y2: root.vertical ? 0 : root.height
                GradientStop { position: 0.0; color: Qt.alpha(root.color, 0.0) }
                GradientStop { position: 0.5; color: Qt.alpha(root.color, 0.38) }
                GradientStop { position: 1.0; color: Qt.alpha(root.color, 0.0) }
            }
            PathSvg { path: "M 0 0 H " + root.width + " V " + root.height + " H 0 Z" }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.vertical ? 1 : root.width
        height: root.vertical ? root.height : 1
        color: root.color
        opacity: root.intensity

        Behavior on color {
            ColorAnimation { duration: Motion.drift; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
        }
    }

    Behavior on intensity {
        NumberAnimation { duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
    }
}
