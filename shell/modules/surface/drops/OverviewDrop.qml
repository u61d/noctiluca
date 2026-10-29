import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

// only the big one is live video, the cards just draw tiles with icons so we don't hold a
// copy of every window in memory. hyprland only refreshes geometry on request, hence the refresh
Item {
    id: root

    property var host: null

    readonly property var monitor: root.host ? root.host.monitor : null
    readonly property real monScale: root.monitor && root.monitor.scale > 0 ? root.monitor.scale : 1
    // layout pixels, same as client positions
    readonly property real monX: root.monitor ? root.monitor.x : 0
    readonly property real monY: root.monitor ? root.monitor.y : 0
    readonly property real monW: root.monitor ? root.monitor.width / root.monScale : 1920
    readonly property real monH: root.monitor ? root.monitor.height / root.monScale : 1080

    readonly property var spaces: {
        const out = [];
        for (const w of Hyprland.workspaces.values) {
            if (!w || w.id < 1) continue;
            if (root.monitor && w.monitor && w.monitor.id !== root.monitor.id) continue;
            out.push(w);
        }
        out.sort(function(a, b) { return a.id - b.id; });
        return out;
    }
    readonly property int activeId: root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id
                                  : Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property int nextFree: {
        let id = 1;
        const used = root.spaces.map(function(w) { return w.id; });
        while (used.indexOf(id) >= 0) id++;
        return id;
    }

    // binding, not a handler: set when `host` arrived it ran before `monitor` was there and
    // always picked the first card
    property int picked: -1
    property bool dragging: false      // a window is being carried; hovering a card mustn't swap the stage
    readonly property int activeIndex: {
        for (let i = 0; i < root.spaces.length; i++)
            if (root.spaces[i].id === root.activeId) return i;
        return 0;
    }
    readonly property int chosen: Math.min(root.picked >= 0 ? root.picked : root.activeIndex, Math.max(0, root.spaces.length - 1))
    readonly property var shown: root.spaces.length > 0 ? root.spaces[root.chosen] : null

    readonly property string wallUrl: Wallpapers.current !== "" ? Paths.fileUrl(Wallpapers.current) : ""

    // about two fifths of the screen height, so it stays a panel and not a second desktop
    readonly property real room: Math.min(860, root.host ? root.host.centreRoom - 52 : 860)
    readonly property real stageH: Math.round(Math.min(root.monH * 0.36, 400, root.room * root.monH / root.monW))
    readonly property real stageW: Math.round(root.stageH * root.monW / root.monH)
    readonly property real cardH: 60
    readonly property real cardW: Math.round(root.cardH * root.monW / root.monH)

    implicitWidth: Math.max(root.stageW, Math.min(root.room, (root.spaces.length + 1) * (root.cardW + 12)))
    implicitHeight: 34 + root.stageH + 18 + root.cardH + 28

    function takeFocus(): void { keys.forceActiveFocus(); }

    Component.onCompleted: {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    function addressOf(t): string { return "address:0x" + t.address; }
    function classOf(t): string {
        const ipc = t.lastIpcObject || {};
        return ipc["class"] || (t.wayland ? t.wayland.appId : "") || "";
    }
    function focusWindow(t): void {
        Hypr.dispatch("hl.dsp.focus({ window = " + Hypr.luaStr(root.addressOf(t)) + " })");
        Panels.close();
    }
    function closeWindow(t): void {
        Hypr.dispatch("hl.dsp.window.close({ window = " + Hypr.luaStr(root.addressOf(t)) + " })");
        refresh.restart();
    }
    function moveWindow(t, wsId: int): void {
        Hypr.dispatch("hl.dsp.window.move({ workspace = " + wsId + ", window = "
                      + Hypr.luaStr(root.addressOf(t)) + ", follow = false })");
        refresh.restart();
    }
    function goTo(wsId: int): void {
        Hypr.focusWorkspace(wsId);
        Panels.close();
    }

    // ask hyprland again once it's applied the move
    Timer {
        id: refresh
        interval: 120
        onTriggered: Hyprland.refreshToplevels()
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
            const n = root.spaces.length;
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab) {
                root.picked = (root.chosen + n - 1) % Math.max(1, n);
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) {
                root.picked = (root.chosen + 1) % Math.max(1, n);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.shown) root.goTo(root.shown.id);
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                root.goTo(event.key - Qt.Key_0);
            } else {
                event.accepted = false;
                return;
            }
            event.accepted = true;
        }
    }

    Row {
        id: heading
        spacing: 12
        Text {
            anchors.baseline: parent.bottom
            text: root.shown ? "Workspace " + root.shown.id : "Overview"
            font.family: Tokens.fontSans; font.pixelSize: 17; font.weight: Font.Medium
            renderType: Text.NativeRendering
            color: Theme.text
        }
        Text {
            anchors.baseline: parent.bottom
            readonly property int n: root.shown && root.shown.toplevels ? root.shown.toplevels.values.length : 0
            text: (root.shown && root.shown.id === root.activeId ? "current, " : "")
                  + (n === 0 ? "empty" : n + (n === 1 ? " window" : " windows"))
            font.family: Tokens.fontSans; font.pixelSize: 13
            renderType: Text.NativeRendering
            color: Theme.mute
        }
        height: 22
    }

    component Space: Item {
        id: sp
        property var view: null          // the overview (an inline component can't see its ids)
        property var ws: null
        property bool large: false
        readonly property real k: sp.width / sp.view.monW
        readonly property var windows: sp.ws && sp.ws.toplevels ? sp.ws.toplevels.values : []

        Rectangle {
            anchors.fill: parent
            color: Theme.surfaceSlate
        }
        Image {
            anchors.fill: parent
            source: sp.view.wallUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: sp.large ? sp.view.stageW : sp.view.cardW * 2
            asynchronous: true
            cache: true
            opacity: 0.85
        }
        Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.surfaceVoid, sp.large ? 0.18 : 0.32) }

        Repeater {
            model: sp.windows
            delegate: Item {
                id: win
                required property var modelData
                readonly property var ipc: win.modelData.lastIpcObject || ({})
                readonly property real homeX: win.ipc.at ? (win.ipc.at[0] - sp.view.monX) * sp.k : 8
                readonly property real homeY: win.ipc.at ? (win.ipc.at[1] - sp.view.monY) * sp.k : 8
                readonly property string appClass: sp.view.classOf(win.modelData)
                readonly property var toplevel: win.modelData

                x: win.homeX
                y: win.homeY
                width: Math.max(sp.large ? 60 : 14, win.ipc.size ? win.ipc.size[0] * sp.k : 120)
                height: Math.max(sp.large ? 40 : 10, win.ipc.size ? win.ipc.size[1] * sp.k : 80)
                z: drag.active ? 10 : 0
                scale: drag.active ? 0.9 : 1
                Behavior on scale { NumberAnimation { duration: Motion.quick } }

                Drag.active: drag.active
                Drag.keys: ["noctiluca-window"]
                Drag.source: win
                Drag.hotSpot.x: win.width / 2
                Drag.hotSpot.y: win.height / 2

                Rectangle {
                    id: tile
                    anchors.fill: parent
                    radius: sp.large ? 8 : 3
                    color: Qt.alpha(Theme.surfaceInk, 0.92)
                    border.width: 1
                    border.color: sp.large && (wh.hovered || drag.active) ? Theme.glow : Qt.rgba(1, 1, 1, sp.large ? 0.12 : 0.16)
                    clip: true

                    Loader {
                        id: liveLoader
                        anchors.fill: parent
                        anchors.margins: 1
                        active: sp.large && Settings.overview.live && !!win.modelData.wayland
                        sourceComponent: ScreencopyView {
                            captureSource: win.modelData.wayland
                            live: true
                            paintCursor: false
                        }
                    }
                    readonly property bool hasLive: liveLoader.item !== null && liveLoader.item.hasContent

                    Column {
                        anchors.centerIn: parent
                        visible: !tile.hasLive
                        spacing: 8
                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.max(8, Math.min(sp.large ? 52 : 18, Math.min(win.width, win.height) * 0.42)); height: width
                            source: Quickshell.iconPath(win.appClass.toLowerCase(), true)
                            visible: this.source != ""
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: sp.large && win.height > 90
                            width: Math.min(win.width - 24, this.implicitWidth)
                            text: win.modelData.title || win.appClass
                            elide: Text.ElideRight
                            font.family: Tokens.fontSans; font.pixelSize: 12
                            renderType: Text.NativeRendering
                            color: Theme.dim
                        }
                    }
                }

                Rectangle {
                    visible: sp.large && wh.hovered && !drag.active
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
                    height: 30
                    radius: 8
                    color: Qt.alpha(Theme.surfaceVoid, 0.82)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    IconImage {
                        id: chipIcon
                        x: 8; anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16
                        source: Quickshell.iconPath(win.appClass.toLowerCase(), true)
                    }
                    Text {
                        anchors { left: chipIcon.right; leftMargin: 8; right: closeBtn.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        text: win.modelData.title || win.appClass
                        elide: Text.ElideRight
                        font.family: Tokens.fontSans; font.pixelSize: 12
                        renderType: Text.NativeRendering
                        color: Theme.text
                    }
                    Item {
                        id: closeBtn
                        width: 22; height: 22
                        anchors.right: parent.right; anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle { anchors.fill: parent; radius: 11; color: xh.hovered ? Qt.alpha(Theme.alert, 0.25) : "transparent" }
                        Icon { anchors.centerIn: parent; path: Icons.close; size: 12; color: xh.hovered ? Theme.alert : Theme.dim }
                        HoverHandler { id: xh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: sp.view.closeWindow(win.modelData) }
                    }
                }

                HoverHandler { id: wh; enabled: sp.large }
                TapHandler { enabled: sp.large; onTapped: sp.view.focusWindow(win.modelData) }
                TapHandler {
                    enabled: sp.large
                    acceptedButtons: Qt.MiddleButton
                    onTapped: sp.view.closeWindow(win.modelData)
                }
                DragHandler {
                    id: drag
                    enabled: sp.large
                    onActiveChanged: {
                        sp.view.dragging = drag.active;
                        if (drag.active) return;
                        win.Drag.drop();
                        win.x = Qt.binding(function() { return win.homeX; });
                        win.y = Qt.binding(function() { return win.homeY; });
                    }
                }
            }
        }
    }

    Item {
        id: stage
        y: 34
        width: root.stageW; height: root.stageH
        anchors.horizontalCenter: parent.horizontalCenter

        // rounded mask, windows inside still take the mouse
        Space {
            id: big
            anchors.fill: parent
            view: root
            ws: root.shown
            large: true
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: stageMask
            }
        }
        Item {
            id: stageMask
            anchors.fill: parent
            layer.enabled: true
            visible: false
            Rectangle { anchors.fill: parent; radius: 15; color: "black" }
        }
        Rectangle {
            anchors.fill: parent
            radius: 15
            color: "transparent"
            border.width: 1
            border.color: root.shown && root.shown.id === root.activeId ? Qt.alpha(Theme.glow, 0.6) : Qt.rgba(1, 1, 1, 0.12)
            Behavior on border.color { ColorAnimation { duration: Motion.base } }
        }
        Text {
            anchors.centerIn: parent
            visible: big.windows.length === 0
            text: "nothing open here"
            font.family: Tokens.fontMono; font.pixelSize: 12
            renderType: Text.NativeRendering
            color: Theme.dim
        }
        Rectangle {
            id: flash
            anchors.fill: parent
            radius: 15
            color: Theme.surfaceInk
            opacity: 0
        }
        Connections {
            target: root
            function onChosenChanged() { flashRun.restart(); }
        }
        NumberAnimation {
            id: flashRun
            target: flash; property: "opacity"; from: 0.6; to: 0
            duration: Motion.base; easing.type: Easing.OutCubic
        }
    }

    Row {
        id: strip
        anchors.horizontalCenter: parent.horizontalCenter
        y: stage.y + stage.height + 18
        spacing: 12

        Repeater {
            model: root.spaces
            delegate: Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool isActive: card.modelData.id === root.activeId
                readonly property bool isChosen: card.index === root.chosen

                width: root.cardW
                height: root.cardH + 26

                Item {
                    id: thumb
                    width: parent.width; height: root.cardH
                    y: card.isChosen ? -4 : 0
                    Behavior on y { NumberAnimation { duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }
                    Space {
                        anchors.fill: parent
                        view: root
                        ws: card.modelData
                        large: false
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: cardMask
                        }
                    }
                    Item {
                        id: cardMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false
                        Rectangle { anchors.fill: parent; radius: 10; color: "black" }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: drop.containsDrag ? Qt.alpha(Theme.glow, 0.16) : ch.hovered && !card.isChosen ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                        border.width: card.isChosen || drop.containsDrag ? 2 : 1
                        border.color: drop.containsDrag || card.isChosen ? Theme.glow : Qt.rgba(1, 1, 1, 0.12)
                        Behavior on border.color { ColorAnimation { duration: Motion.quick } }
                    }
                    DropArea {
                        id: drop
                        anchors.fill: parent
                        keys: ["noctiluca-window"]
                        onDropped: function(ev) {
                            const t = ev.source ? ev.source.toplevel : null;
                            if (t && t.workspace !== card.modelData) root.moveWindow(t, card.modelData.id);
                        }
                    }
                    HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (this.hovered && !root.dragging) root.picked = card.index }
                    TapHandler { onTapped: root.goTo(card.modelData.id) }
                }

                Row {
                    anchors { top: thumb.bottom; topMargin: 8; horizontalCenter: parent.horizontalCenter }
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.isActive
                        width: 5; height: 5; radius: 2.5
                        color: Theme.glow
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.modelData.id
                        font.family: Tokens.fontMono; font.pixelSize: 12
                        font.weight: card.isChosen ? Font.DemiBold : Font.Normal
                        renderType: Text.NativeRendering
                        color: card.isChosen ? Theme.text : Theme.dim
                    }
                }
            }
        }

        Item {
            width: root.cardH; height: root.cardH + 26
            Rectangle {
                width: parent.width; height: root.cardH
                radius: 10
                color: nh.hovered || ndrop.containsDrag ? Qt.alpha(Theme.glow, 0.1) : Qt.rgba(1, 1, 1, 0.025)
                border.width: 1
                border.color: nh.hovered || ndrop.containsDrag ? Qt.alpha(Theme.glow, 0.6) : Qt.rgba(1, 1, 1, 0.1)
                Icon { anchors.centerIn: parent; path: Icons.plus; size: 20; color: nh.hovered ? Theme.glowHi : Theme.mute }
                DropArea {
                    id: ndrop
                    anchors.fill: parent
                    keys: ["noctiluca-window"]
                    onDropped: function(ev) {
                        const t = ev.source ? ev.source.toplevel : null;
                        if (t) root.moveWindow(t, root.nextFree);
                    }
                }
                HoverHandler { id: nh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.goTo(root.nextFree) }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.cardH + 8
                text: "new"
                font.family: Tokens.fontMono; font.pixelSize: 11
                renderType: Text.NativeRendering
                color: Theme.mute
            }
        }
    }
}
