import QtQuick
import qs.core
import qs.services
import qs.modules.polkit
import qs.modules.capture

Item {
    width: 1920; height: 1080
    Image { anchors.fill: parent; source: "sea.png"; fillMode: Image.PreserveAspectCrop }
    Loader {
        anchors.fill: parent
        sourceComponent: "@WHICH@" === "polkit" ? polkit : capture
    }
    Component { id: polkit; PolkitPrompt {} }
    Component { id: capture; Capture {} }
    Component.onCompleted: if ("@WHICH@" === "capture") Shot.selecting = true
}
