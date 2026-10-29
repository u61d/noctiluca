import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.core
import qs.components

// the lens has two edges on two springs; the leading one is quicker, so going from 2 to 5
// it reaches ahead and the back catches up
Item {
    id: root

    property var monitor: null

    readonly property string style: Settings.bar.workspaceStyle
    readonly property bool lens: root.style !== "motes"
    readonly property bool icons: root.style === "lens"
    readonly property bool reading: area.hovered || root.style === "numbers"

    // at least the setting, more while higher ones are in use, never past nine
    readonly property int slots: {
        let hi = Math.max(1, Settings.bar.workspaces);
        for (const w of Hyprland.workspaces.values)
            if (w && w.id > hi && w.id <= 9) hi = w.id;
        if (root.activeId > hi && root.activeId <= 9) hi = root.activeId;
        return hi;
    }

    readonly property var wsById: {
        const out = {};
        for (const w of Hyprland.workspaces.values) {
            if (!w || w.id < 1) continue;
            if (root.monitor && w.monitor && w.monitor.id !== root.monitor.id) continue;
            out[w.id] = w;
        }
        return out;
    }
    readonly property int realActiveId: {
        const m = root.monitor;
        if (m && m.activeWorkspace) return m.activeWorkspace.id;
        return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
    }
    // where you asked to go, until hyprland catches up. the lens moves straight away and fast
    // scrolling counts from here, not from where hyprland got to
    property int heading: -1
    readonly property int activeId: root.heading > 0 ? root.heading : root.realActiveId
    onRealActiveIdChanged: if (root.realActiveId === root.heading) root.heading = -1
    Timer { id: headingGiveUp; interval: 700; onTriggered: root.heading = -1 }
    function go(id: int): void {
        root.heading = id;
        headingGiveUp.restart();
        Hypr.focusWorkspace(id);
    }

    function windowsOf(id: int): var {
        const w = root.wsById[id];
        return w && w.toplevels ? w.toplevels.values : [];
    }
    function appOf(t: var): string {
        if (t.wayland && t.wayland.appId) return t.wayland.appId;
        const ipc = t.lastIpcObject || {};
        return ipc["class"] || ipc.initialClass || "";
    }
    function appsOf(id: int): var {
        const seen = [];
        for (const t of root.windowsOf(id)) {
            const a = root.appOf(t);
            if (a !== "" && seen.indexOf(a) < 0) seen.push(a);
        }
        return seen;
    }
    function iconFor(app: string): string {
        const entry = DesktopEntries.heuristicLookup(app);
        const name = entry && entry.icon ? entry.icon : app.toLowerCase();
        return Quickshell.iconPath(name, true);
    }

    readonly property int slotW: root.style === "motes" ? 18 : 22
    readonly property int iconSize: 16
    readonly property int maxIcons: 3
    readonly property var activeApps: root.icons ? root.appsOf(root.activeId) : []
    readonly property int shownIcons: Math.min(root.activeApps.length, root.maxIcons)
    readonly property int extra: root.activeApps.length - root.shownIcons

    readonly property real activeW: {
        if (!root.lens) return root.slotW;
        if (root.shownIcons === 0) return 30;
        return 12 + 8 + 9 + root.shownIcons * (root.iconSize + 6) - 6 + (root.extra > 0 ? 18 : 0) + 11;
    }
    function slotWidth(id: int): real { return id === root.activeId ? root.activeW : root.slotW; }
    function slotX(id: int): real {
        let x = 0;
        for (let i = 1; i < id; i++) x += root.slotWidth(i);
        return x;
    }
    readonly property real totalW: {
        let x = 0;
        for (let i = 1; i <= root.slots; i++) x += root.slotWidth(i);
        return x;
    }

    readonly property real activeX: root.slotX(root.activeId) + root.activeW / 2

    implicitWidth: widthSpring.value
    implicitHeight: 32

    Spring { id: widthSpring; kind: "morph"; target: root.totalW; epsilon: 0.2 }

    readonly property real wantL: root.slotX(root.activeId)
    readonly property real wantR: root.wantL + root.activeW
    onWantLChanged: Qt.callLater(root.place)
    onWantRChanged: Qt.callLater(root.place)
    Component.onCompleted: { lEdge.snap(root.wantL); rEdge.snap(root.wantR); }

    function place(): void {
        const forward = root.wantR > rEdge.target;
        const back = root.wantL < lEdge.target;
        lEdge.kind = back && !forward ? "nudge" : forward && !back ? "morph" : "nudge";
        rEdge.kind = forward && !back ? "nudge" : back && !forward ? "morph" : "nudge";
        lEdge.target = root.wantL;
        rEdge.target = root.wantR;
    }

    readonly property bool arrived: Math.abs(lEdge.value - root.wantL) < 4 && Math.abs(rEdge.value - root.wantR) < 4

    Spring { id: lEdge; kind: "nudge"; epsilon: 0.15 }
    Spring { id: rEdge; kind: "nudge"; epsilon: 0.15 }

    readonly property real strain: Math.min(1, Math.max(0, (rEdge.value - lEdge.value - root.activeW) / 60))

    Item {
        id: lensShape
        x: lEdge.value
        width: Math.max(6, rEdge.value - lEdge.value)
        height: root.height
        visible: root.lens

        Rectangle {
            id: lensBody
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 24 - root.strain * 6
            radius: height / 2
            color: Qt.alpha(Theme.glow, 0.11 + root.strain * 0.05)
            border.width: 1
            border.color: Qt.alpha(Theme.glow, 0.38)
        }
        Rectangle {
            x: lensBody.radius * 0.6
            y: lensBody.y + lensBody.height - 2
            width: Math.max(0, parent.width - lensBody.radius * 1.2)
            height: 1
            color: Theme.glowHi
            opacity: 0.3
        }
    }

    Rectangle {
        visible: !root.lens
        x: lEdge.value + 2
        y: root.height / 2 - 2.5
        width: Math.max(4, rEdge.value - lEdge.value - 4)
        height: 5
        radius: 2.5
        color: Theme.glowHi
        opacity: root.reading ? 0.3 : 1
        Behavior on opacity { NumberAnimation { duration: Motion.quick } }

        Repeater {
            model: 3
            delegate: Rectangle {
                required property int index
                anchors.centerIn: parent
                width: parent.width + 4 + index * 4; height: parent.height + 4 + index * 4
                radius: height / 2
                color: Theme.glow
                opacity: 0.09 - index * 0.025
                z: -1
            }
        }
    }

    HoverHandler { id: area }

    Repeater {
        model: root.slots

        delegate: Item {
            id: slot
            required property int index
            readonly property int wsId: slot.index + 1
            readonly property var ws: root.wsById[slot.wsId] || null
            readonly property bool isActive: slot.wsId === root.activeId
            readonly property int count: root.windowsOf(slot.wsId).length
            readonly property bool urgent: slot.ws !== null && slot.ws.urgent

            x: root.slotX(slot.wsId)
            width: root.slotWidth(slot.wsId)
            height: root.height
            Behavior on x {
                NumberAnimation { duration: Motion.smooth; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
            }

            Item {
                anchors.fill: parent
                opacity: slot.isActive && root.lens ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Motion.quick } }

                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    opacity: root.reading || slot.isActive ? 0 : 1
                    scale: root.reading ? 0.6 : 1
                    Behavior on opacity { NumberAnimation { duration: Motion.quick } }
                    Behavior on scale { NumberAnimation { duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }

                    Repeater {
                        model: Math.max(1, Math.min(3, slot.count))
                        delegate: Rectangle {
                            width: 3; height: 3; radius: 1.5
                            color: slot.urgent ? Theme.alert
                                 : slot.count > 0 ? (dotHover.hovered ? Theme.glowHi : Theme.glow)
                                 : Theme.mute
                            opacity: slot.count > 0 ? 0.85 : 0.45
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -0.5
                    text: slot.wsId
                    font.family: Tokens.fontMono
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                    color: slot.urgent ? Theme.alert
                         : dotHover.hovered || slot.isActive ? Theme.text
                         : slot.count > 0 ? Theme.dim : Qt.alpha(Theme.mute, 0.7)
                    opacity: root.reading ? 1 : 0
                    scale: root.reading ? 1 : 1.3
                    Behavior on opacity { NumberAnimation { duration: Motion.quick } }
                    Behavior on scale { NumberAnimation { duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }
                }

                SequentialAnimation on opacity {
                    running: slot.urgent && !slot.isActive
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.35; duration: Motion.scaled(700); easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: Motion.scaled(700); easing.type: Easing.InOutSine }
                }
            }

            Row {
                visible: root.lens
                x: root.icons && root.shownIcons > 0 ? 12 : (parent.width - this.implicitWidth) / 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                // in as the lens arrives, not after its wobble settles
                opacity: slot.isActive && root.arrived ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.quick } }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -0.5
                    width: 9
                    horizontalAlignment: Text.AlignHCenter
                    text: slot.wsId
                    font.family: Tokens.fontMono
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    color: Theme.text
                }

                Row {
                    visible: root.icons && slot.isActive && root.shownIcons > 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: slot.isActive ? root.activeApps.slice(0, root.maxIcons) : []
                        delegate: Item {
                            id: app
                            required property string modelData
                            readonly property string src: root.iconFor(app.modelData)
                            width: root.iconSize; height: root.iconSize

                            IconImage {
                                id: img
                                anchors.fill: parent
                                source: app.src
                                visible: app.src !== "" && !Settings.bar.tintIcons
                                asynchronous: true
                            }
                            // tinted so a row of brand colours reads as one thing
                            MultiEffect {
                                anchors.fill: parent
                                source: img
                                visible: app.src !== "" && Settings.bar.tintIcons
                                colorization: 1.0
                                colorizationColor: Theme.glowHi
                                brightness: 0.15
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: app.src === ""
                                text: app.modelData.charAt(0).toUpperCase()
                                font.family: Tokens.fontMono
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                                color: Theme.glowHi
                            }
                        }
                    }

                    Text {
                        visible: root.extra > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+" + root.extra
                        font.family: Tokens.fontMono
                        font.pixelSize: 10
                        renderType: Text.NativeRendering
                        color: Theme.dim
                    }
                }
            }

            HoverHandler { id: dotHover; cursorShape: Qt.PointingHandCursor }

            TapHandler {
                onTapped: {
                    root.go(slot.wsId);                   // empty ones too: Hyprland creates it
                }
            }
        }
    }

    property real wheelRest: 0
    function scroll(dy: real): void {
        root.wheelRest += dy;
        if (Math.abs(root.wheelRest) < 120 || wheelPause.running) return;
        const dir = root.wheelRest > 0 ? -1 : 1;
        root.wheelRest = 0;
        const next = Math.max(1, Math.min(root.slots, root.activeId + dir));
        if (next === root.activeId) return;
        root.go(next);
        wheelPause.restart();
    }
    // a fast flick shouldn't skip four workspaces
    Timer { id: wheelPause; interval: 45 }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            // touchpads report pixels; scale so a short swipe is one step
            const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y * 4 : event.angleDelta.y;
            root.scroll(dy);
        }
    }
}
