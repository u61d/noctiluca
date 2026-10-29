import QtQuick
import qs.core

// properties are uploaded to waterline.frag uniforms by name, rename both sides together
// pool  = (x0, x1, depth, radius), off when x1 <= x0
// drop  = (x, y, w, h), off when w or h <= 0
// bend  = (belly px, narrowing px, -, -)
// pulse = (x, y, age 0..1, strength)
ShaderEffect {
    id: root

    property size size: Qt.size(root.width, root.height)
    property real line: 4
    property real poolBlend: 16
    property real dropBlend: 22
    property real dropRadius: 22

    property vector4d pool0: Qt.vector4d(0, 0, 0, 0)
    property vector4d pool1: Qt.vector4d(0, 0, 0, 0)
    property vector4d pool2: Qt.vector4d(0, 0, 0, 0)
    property vector4d drop0: Qt.vector4d(0, 0, 0, 0)
    property vector4d drop1: Qt.vector4d(0, 0, 0, 0)
    property vector4d drop2: Qt.vector4d(0, 0, 0, 0)
    property vector4d bend0: Qt.vector4d(0, 0, 0, 0)
    property vector4d bend1: Qt.vector4d(0, 0, 0, 0)
    property vector4d bend2: Qt.vector4d(0, 0, 0, 0)

    property color ink: Qt.alpha(Theme.surfaceVoid, Settings.appearance.inkOpacity)
    property color inkDeep: Qt.alpha(Qt.darker(Theme.surfaceVoid, 1.6), Settings.appearance.inkOpacity)
    property color glow: Theme.glow

    property point cursor: Qt.point(-1, -1)
    property real rimBase: 0.22
    property real light: Settings.appearance.light

    property vector4d ripple: Qt.vector4d(0, 1, 0, 0)
    property vector4d pulse0: Qt.vector4d(0, 0, 1, 0)
    property vector4d pulse1: Qt.vector4d(0, 0, 1, 0)
    property vector4d pulse2: Qt.vector4d(0, 0, 1, 0)
    property vector4d pulse3: Qt.vector4d(0, 0, 1, 0)

    fragmentShader: Qt.resolvedUrl("../shaders/waterline.frag.qsb")
    blending: true
}
