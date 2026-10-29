// TIMELINE becomes a list of [ms, function] pairs. the clock is an animation so it moves
// with the captured frames, not the wall clock
import QtQuick
import Quickshell.Hyprland
import qs.core
import qs.services
import qs.modules.surface

Item {
    id: scene
    width: 1920; height: 1080

    Image { anchors.fill: parent; source: "sea.png"; fillMode: Image.PreserveAspectCrop }

    Surface {
        id: surface
        modelData: ({ name: "DP-1" })
        width: 1920; height: 1080
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
