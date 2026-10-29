import QtQuick
import QtQuick.Shapes
import qs.core

Item {
    id: root

    property var values: []          // oldest first
    property real max: 1             // the value at the top; for rates, pass the window's peak
    property int capacity: 60        // how many samples fit across
    property int stepMs: 2000        // how long one sample lasts, for the slide
    property color color: Theme.glow
    property real fillStrength: 0.22
    property bool dot: true

    readonly property real step: root.width / Math.max(1, root.capacity - 1)
    property real shift: 0

    clip: true

    onValuesChanged: {
        slide.stop();
        root.shift = root.step;
        slide.start();
    }
    NumberAnimation {
        id: slide
        target: root; property: "shift"; to: 0
        duration: Motion.reduced ? 0 : root.stepMs
    }

    function points(): var {
        const v = root.values || [];
        const n = v.length;
        const out = [];
        const top = 2, bottom = root.height - 1;
        for (let i = 0; i < n; i++) {
            const x = root.width - (n - 1 - i) * root.step + root.shift;
            const y = bottom - Math.max(0, Math.min(1, v[i] / Math.max(1e-9, root.max))) * (bottom - top);
            out.push({ x: x, y: y });
        }
        return out;
    }

    // catmull-rom as cubic béziers
    function curve(p: var): string {
        if (p.length === 0) return "";
        if (p.length === 1) return "M " + p[0].x + " " + p[0].y;
        let d = "M " + p[0].x.toFixed(2) + " " + p[0].y.toFixed(2);
        for (let i = 0; i < p.length - 1; i++) {
            const a = p[Math.max(0, i - 1)], b = p[i], c = p[i + 1], e = p[Math.min(p.length - 1, i + 2)];
            const c1x = b.x + (c.x - a.x) / 6, c1y = b.y + (c.y - a.y) / 6;
            const c2x = c.x - (e.x - b.x) / 6, c2y = c.y - (e.y - b.y) / 6;
            d += " C " + c1x.toFixed(2) + " " + c1y.toFixed(2) + " " + c2x.toFixed(2) + " " + c2y.toFixed(2)
               + " " + c.x.toFixed(2) + " " + c.y.toFixed(2);
        }
        return d;
    }

    readonly property var pts: root.points()
    readonly property string line: root.curve(root.pts)
    readonly property string area: root.pts.length < 2 ? ""
        : root.line + " L " + root.pts[root.pts.length - 1].x.toFixed(2) + " " + root.height
          + " L " + root.pts[0].x.toFixed(2) + " " + root.height + " Z"

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: Qt.alpha(Theme.line, 0.7)
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: root.height
                GradientStop { position: 0.0; color: Qt.alpha(root.color, root.fillStrength) }
                GradientStop { position: 1.0; color: Qt.alpha(root.color, 0.0) }
            }
            PathSvg { path: root.area }
        }
        ShapePath {
            strokeColor: Qt.alpha(root.color, 0.18)
            strokeWidth: 4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.line }
        }
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.line }
        }
    }

    Rectangle {
        visible: root.dot && root.pts.length > 0
        readonly property var last: root.pts.length > 0 ? root.pts[root.pts.length - 1] : ({ x: 0, y: 0 })
        x: Math.min(root.width - 3, last.x) - 2.5
        y: last.y - 2.5
        width: 5; height: 5; radius: 2.5
        color: Theme.glowHi
        Rectangle {
            anchors.centerIn: parent
            width: 13; height: 13; radius: 6.5
            color: root.color
            opacity: 0.16
        }
    }
}
