import QtQuick
import qs.core

// usually the overview on a quickshell built without screencopy
Item {
    id: root

    property var host: null
    readonly property string which: root.host ? root.host.failed : ""

    implicitWidth: 420
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 8

        Text {
            text: "The " + (root.which || "panel") + " could not be loaded"
            font.family: Tokens.fontSans; font.pixelSize: 12; font.weight: Font.Medium
            renderType: Text.NativeRendering
            color: Theme.alert
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.which === "overview"
                  ? "The overview needs a Quickshell built with screencopy. Rebuild it once with scripts/build-quickshell.sh, then restart the shell."
                  : "Its errors are in the shell log: noctiluca-shell log"
            font.family: Tokens.fontSans; font.pixelSize: 13
            renderType: Text.NativeRendering
            color: Theme.dim
        }
    }
}
