import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: win.modelData
            visible: Shot.selecting
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: Tokens.nsCapture
            WlrLayershell.keyboardFocus: Shot.selecting ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            property point from: Qt.point(0, 0)
            property point to: Qt.point(0, 0)
            property bool dragging: false
            readonly property real sx: Math.min(win.from.x, win.to.x)
            readonly property real sy: Math.min(win.from.y, win.to.y)
            readonly property real sw: Math.abs(win.to.x - win.from.x)
            readonly property real sh: Math.abs(win.to.y - win.from.y)
            readonly property real shade: 0.45

            onVisibleChanged: {
                win.dragging = false;
                win.from = win.to = Qt.point(0, 0);
                if (visible) keys.forceActiveFocus();
            }

            Rectangle { x: 0; y: 0; width: parent.width; height: win.sy; color: "black"; opacity: win.shade }
            Rectangle { x: 0; y: win.sy + win.sh; width: parent.width; height: parent.height - win.sy - win.sh; color: "black"; opacity: win.shade }
            Rectangle { x: 0; y: win.sy; width: win.sx; height: win.sh; color: "black"; opacity: win.shade }
            Rectangle { x: win.sx + win.sw; y: win.sy; width: parent.width - win.sx - win.sw; height: win.sh; color: "black"; opacity: win.shade }

            Rectangle {
                x: win.sx - 1; y: win.sy - 1
                width: win.sw + 2; height: win.sh + 2
                visible: win.sw > 0
                color: "transparent"
                radius: 2
                border.width: 1
                border.color: Theme.glow
            }

            Rectangle { visible: !win.dragging && pointer.hovered; x: 0; y: pointer.point.position.y; width: parent.width; height: 1; color: Qt.alpha(Theme.glow, 0.45) }
            Rectangle { visible: !win.dragging && pointer.hovered; x: pointer.point.position.x; y: 0; width: 1; height: parent.height; color: Qt.alpha(Theme.glow, 0.45) }

            Text {
                visible: win.sw > 0
                x: Math.min(win.sx + win.sw + 10, win.width - width - 10)
                y: Math.min(win.sy + win.sh + 8, win.height - height - 10)
                text: Math.round(win.sw) + " × " + Math.round(win.sh)
                font.family: Tokens.fontMono
                font.pixelSize: 12
                renderType: Text.NativeRendering
                color: Theme.text
                style: Text.Outline
                styleColor: "#80000000"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 64
                visible: !win.dragging
                text: "Drag across what you want, or click a window. Esc cancels."
                font.family: Tokens.fontMono
                font.pixelSize: 12
                renderType: Text.NativeRendering
                color: Theme.dim
            }

            HoverHandler { id: pointer; cursorShape: Qt.CrossCursor }

            DragHandler {
                target: null
                dragThreshold: 4
                onActiveChanged: {
                    if (this.active) {
                        win.dragging = true;
                        win.from = this.centroid.pressPosition;
                        win.to = this.centroid.position;
                    } else if (win.dragging) {
                        win.dragging = false;
                        const g = win.global(win.sx, win.sy);
                        Shot.rect(g.x, g.y, win.sw, win.sh);
                    }
                }
                onCentroidChanged: if (this.active) win.to = this.centroid.position
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: function(point, button) {
                    if (button === Qt.RightButton) {
                        Shot.cancel();
                        return;
                    }
                    const g = win.global(point.position.x, point.position.y);
                    const r = win.windowAt(g.x, g.y);
                    if (r) Shot.rect(r.x, r.y, r.w, r.h);
                    else Shot.rect(win.screen.x, win.screen.y, win.width, win.height);
                }
            }

            function global(x: real, y: real): point {
                return Qt.point(x + win.screen.x, y + win.screen.y);
            }

            // smallest window containing the point, which is the one on top in practice
            function windowAt(x: real, y: real): var {
                const mon = Hyprland.monitorFor(win.screen);
                const ws = mon && mon.activeWorkspace ? mon.activeWorkspace.id : -1;
                let best = null;
                for (const t of Hyprland.toplevels.values) {
                    const o = t.lastIpcObject;
                    if (!o || !o.at || !o.size || !o.workspace || o.workspace.id !== ws) continue;
                    const r = { x: o.at[0], y: o.at[1], w: o.size[0], h: o.size[1] };
                    if (x < r.x || y < r.y || x > r.x + r.w || y > r.y + r.h) continue;
                    if (!best || r.w * r.h < best.w * best.h) best = r;
                }
                return best;
            }

            Item {
                id: keys
                focus: true
                Keys.onEscapePressed: Shot.cancel()
                Keys.onReturnPressed: Shot.rect(win.screen.x, win.screen.y, win.width, win.height)
            }
        }
    }
}
