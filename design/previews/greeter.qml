import QtQuick
import qs.core
import qs.services
import qs.modules.greeter

Item {
    width: 1920; height: 1080
    Greeter { id: greeter }
    Component.onCompleted: {
        Wallpapers._current = Qt.resolvedUrl("sea.png").toString().replace("file://", "");
    }
    Timer {
        interval: 2600; running: true
        onTriggered: {
            greeter.users = [{ name: "u61d", full: "" }, { name: "ana", full: "Ana" }, { name: "jonas", full: "Jonas" }];
            greeter.host = "halcyon";
            greeter.sessions = [{ name: "Hyprland", exec: "Hyprland" }, { name: "Plasma (Wayland)", exec: "startplasma-wayland" }];
        }
    }
}
