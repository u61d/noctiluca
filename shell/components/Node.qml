import QtQuick
import QtQuick.Shapes
import qs.core

Item {
    id: root

    property color color: Theme.glow
    property real core: 4            // diameter of the solid centre
    property real halo: 3            // how far the light reaches beyond the core
    property real intensity: 1.0     // 0 = dark, 1 = full
    property bool breathing: false

    implicitWidth: root.core + root.halo * 2
    implicitHeight: root.core + root.halo * 2

    Shape {
        id: haloShape
        anchors.fill: parent
        asynchronous: false
        opacity: root.intensity * 0.75 * (root.breathing ? breathe.value : 1.0)

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.width / 2
                centerY: root.height / 2
                centerRadius: root.width / 2
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0.0; color: Qt.alpha(root.color, 0.90) }
                GradientStop { position: 0.35; color: Qt.alpha(root.color, 0.25) }
                GradientStop { position: 1.0; color: Qt.alpha(root.color, 0.0) }
            }
            PathSvg { path: "M 0 0 H " + root.width + " V " + root.height + " H 0 Z" }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.core
        height: root.core
        radius: width / 2
        color: root.color
        opacity: root.intensity

        Behavior on color {
            ColorAnimation { duration: Motion.drift; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
        }
    }

    Behavior on intensity {
        NumberAnimation { duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
    }

    // only breathes while visible
    QtObject {
        id: breathe
        property real value: 1.0
    }

    SequentialAnimation {
        running: root.breathing && root.visible
        loops: Animation.Infinite
        alwaysRunToEnd: false
        NumberAnimation { target: breathe; property: "value"; from: 1.0; to: 0.45; duration: Motion.breath / 2; easing.type: Easing.InOutSine }
        NumberAnimation { target: breathe; property: "value"; from: 0.45; to: 1.0; duration: Motion.breath / 2; easing.type: Easing.InOutSine }
    }
}
