import QtQuick
import QtQuick.Shapes
import qs.core

// stroke is in grid units so every size has the same weight, like lucide
Item {
    id: root

    property string path: ""
    property color color: Theme.dim
    property real size: 16
    property real weight: 1.9

    implicitWidth: root.size
    implicitHeight: root.size

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        asynchronous: false
        preferredRendererType: Shape.CurveRenderer
        visible: root.path !== ""

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.weight
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg { path: root.path }
        }

        Behavior on opacity {
            NumberAnimation { duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
        }
    }
}
