import QtQuick
import qs.core
import qs.services

Item {
    id: root

    property real radius: 110           // where the bars start, from the centre
    property real reach: 26              // how far the loudest band goes out
    property color color: Players.accent
    property bool live: true

    readonly property int count: Math.max(8, Cava.bars * 2)

    implicitWidth: (root.radius + root.reach) * 2 + 8
    implicitHeight: implicitWidth

    Repeater {
        model: root.count
        delegate: Item {
            id: spoke
            required property int index
            anchors.fill: parent
            rotation: spoke.index * 360 / root.count
            // mirrored, so bass is at the top
            readonly property int band: spoke.index < Cava.bars ? spoke.index : root.count - 1 - spoke.index
            readonly property real level: {
                const l = Cava.levels;
                return root.live && l && spoke.band < l.length ? l[spoke.band] : 0;
            }
            Rectangle {
                x: root.width / 2 - width / 2
                width: 2.5
                height: 3 + spoke.level * root.reach
                y: root.height / 2 - root.radius - height
                radius: width / 2
                color: root.color
                opacity: 0.28 + spoke.level * 0.7
                Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            }
        }
    }
}
