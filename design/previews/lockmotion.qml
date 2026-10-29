import QtQuick
import qs.core
import qs.services
import qs.modules.lock

Item {
    id: scene
    width: 1920; height: 1080

    Lock { id: lock }

    Component.onCompleted: {
        Wallpapers._current = Qt.resolvedUrl("sea.png").toString().replace("file://", "");
    }

    property var timeline: [@TIMELINE@]
    property int nextEvent: 0
    property real t: 0
    NumberAnimation on t { from: 0; to: 1e7; duration: 1e7 }
    onTChanged: {
        while (scene.nextEvent < scene.timeline.length && scene.timeline[scene.nextEvent][0] <= scene.t) {
            scene.timeline[scene.nextEvent][1]();
            scene.nextEvent++;
        }
    }
}
