// python3 tests/render_qml.py design/previews/surface.qml out.png --gpu --scene --wait=1400
import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Hyprland
import qs.core
import qs.services
import qs.modules.surface

Item {
    width: 1920; height: 1080

    Image { anchors.fill: parent; source: "sea.png"; fillMode: Image.PreserveAspectCrop }

    Surface {
        modelData: ({ name: "DP-1" })
        width: 1920; height: 1080
    }

    Timer {
        interval: 200; running: true
        onTriggered: {
            @SETUP@
            Panels.current = "@PANEL@";
        }
    }
    // for state a panel resets when it opens (lyrics, spectrum)
    Timer {
        interval: 2600; running: true
        onTriggered: {
            @LATER@
        }
    }
    // for things that only show while they keep happening (volume popup)
    Timer {
        interval: 700; repeat: true; running: true
        property int n: 0
        onTriggered: {
            n++;
            @EVERY@
        }
    }
}
