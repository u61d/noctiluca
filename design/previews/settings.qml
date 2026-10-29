import QtQuick
import qs.core
import qs.services
import qs.modules.settings

Item {
    width: 1080; height: 720
    Component.onCompleted: Panels.settingsPage = "@PAGE@"
    SettingsWindow {
        anchors.fill: parent
    }
}
