import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core

// the surface runs in ExclusionMode.Ignore to reach the edges and can't have an exclusive
// zone, so this 1px window reserves the bar's strip instead
PanelWindow {
    id: win

    required property var modelData
    screen: win.modelData

    WlrLayershell.namespace: Tokens.nsExclusion
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; left: true; right: true }
    implicitHeight: 1
    exclusiveZone: Tokens.surfaceDepth
    color: "transparent"

    mask: Region {}
}
