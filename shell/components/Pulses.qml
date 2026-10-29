import QtQuick
import qs.core

// max four pulses (waterline.frag has four slots), a fifth reuses the oldest
QtObject {
    id: root

    property int next: 0
    property int duration: Motion.scaled(1100)

    readonly property vector4d p0: Qt.vector4d(a.x, a.y, a.age, a.strength)
    readonly property vector4d p1: Qt.vector4d(b.x, b.y, b.age, b.strength)
    readonly property vector4d p2: Qt.vector4d(c.x, c.y, c.age, c.strength)
    readonly property vector4d p3: Qt.vector4d(d.x, d.y, d.age, d.strength)

    property QtObject a: QtObject { property real x; property real y; property real age: 1; property real strength: 0 }
    property QtObject b: QtObject { property real x; property real y; property real age: 1; property real strength: 0 }
    property QtObject c: QtObject { property real x; property real y; property real age: 1; property real strength: 0 }
    property QtObject d: QtObject { property real x; property real y; property real age: 1; property real strength: 0 }

    property NumberAnimation runA: NumberAnimation { target: root.a; property: "age"; from: 0; to: 1; duration: root.duration }
    property NumberAnimation runB: NumberAnimation { target: root.b; property: "age"; from: 0; to: 1; duration: root.duration }
    property NumberAnimation runC: NumberAnimation { target: root.c; property: "age"; from: 0; to: 1; duration: root.duration }
    property NumberAnimation runD: NumberAnimation { target: root.d; property: "age"; from: 0; to: 1; duration: root.duration }

    function emit(x: real, y: real, strength: real): void {
        const slots = [[root.a, root.runA], [root.b, root.runB], [root.c, root.runC], [root.d, root.runD]];
        const s = slots[root.next];
        root.next = (root.next + 1) % 4;
        s[0].x = x;
        s[0].y = y;
        s[0].strength = strength;
        s[1].restart();
    }
}
