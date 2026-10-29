import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services
import qs.modules.surface.pools
import qs.modules.surface.drops

// one fullscreen layer per screen, the ink is a single shader. clicks pass through
// everywhere but the ink (`mask`). two sheets so a side panel can close while a centre one
// opens.
PanelWindow {
    id: win

    required property var modelData
    screen: win.modelData

    WlrLayershell.namespace: Tokens.nsSurface
    WlrLayershell.layer: WlrLayer.Top
    // keyboard only while a panel or a toast is up, so the bar never steals a key
    WlrLayershell.keyboardFocus: win.hosting && (Panels.isOpen || win.toastsShowing)
                                 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // Exclusion.qml reserves the strip, a window in this mode can't
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    readonly property real line: 4
    readonly property real depth: Tokens.surfaceDepth
    readonly property real centreDepth: Tokens.surfaceDepth - 6
    readonly property real gutter: 26
    readonly property real edge: 16
    readonly property real contentTop: win.depth + 14
    readonly property real rise: 22

    readonly property bool hosting: Panels.screenName === "" || (win.screen && win.screen.name === Panels.screenName)
    readonly property var monitor: Hyprland.monitorFor(win.screen)

    // fullscreen window: the ink tucks up into the edge until you need it
    readonly property var activeWs: win.monitor ? win.monitor.activeWorkspace : null
    readonly property bool fullscreenHere: Settings.bar.hideOnFullscreen && win.activeWs !== null
                                           && win.activeWs.hasFullscreen === true
    property bool peeking: false
    readonly property bool tucked: win.fullscreenHere && !win.anyOpen && !win.toastsShowing && !win.peeking
    Spring { id: lift; kind: "morph"; target: win.tucked ? 0 : 1; epsilon: 0.002 }
    onTuckedChanged: if (!win.tucked) peekLeave.stop()
    Timer { id: peekLeave; interval: 700; onTriggered: win.peeking = false }

    Spring { id: leftEdge; target: win.gutter + left.implicitWidth + win.gutter }
    Spring { id: rightEdge; target: win.width - (win.gutter + status.implicitWidth + win.gutter) }
    Spring { id: centreWidth; target: centre.present ? centre.implicitWidth : 0 }
    Spring { id: centreFill; target: centre.present && !win.centreYields ? (centre.depth > 0 ? centre.depth : win.centreDepth) : 0 }

    // a wide right panel would melt into the centre pool, so drain it
    readonly property bool centreYields: {
        const s = win.mainSheet;
        return s.open && s.side === "right" && s.wantX < win.width / 2 + centre.implicitWidth / 2 + 48;
    }

    // centre panels have to fit between the side pools
    readonly property real centreRoom: 2 * Math.min(win.width / 2 - (win.gutter * 2 + spaces.implicitWidth),
                                                    rightEdge.target - win.width / 2) - 72
    readonly property bool centreOpen: (sheetA.open && sheetA.side === "centre") || (sheetB.open && sheetB.side === "centre")
    readonly property bool anyOpen: sheetA.open || sheetB.open
    readonly property bool toastsShowing: toastSheet.open

    property bool useA: true
    readonly property Sheet mainSheet: win.useA ? sheetA : sheetB
    readonly property Sheet otherSheet: win.useA ? sheetB : sheetA
    readonly property string wanted: win.hosting ? Panels.current : ""
    property string failed: ""

    onWantedChanged: win.route()

    function route(): void {
        const name = win.wanted;
        const cur = win.mainSheet;
        win.waitingFor = null;
        if (name === "") {
            sheetA.open = false;
            sheetB.open = false;
            return;
        }
        const side = Panels.anchorOf(name);
        const url = win.dropFile(name);
        if (cur.open && cur.side === side) {
            cur.source = url;
            if (cur.item && cur.item.takeFocus) cur.item.takeFocus();
            return;
        }
        cur.open = false;
        const next = cur.active ? win.otherSheet : cur;
        if (next !== cur) win.useA = !win.useA;
        next.side = side;
        next.source = url;
        // old sheet gets mostly out of the way first so they never overlap
        if (next !== cur && cur.p > 0.3) {
            win.waitingFor = cur;
            win.toOpen = next;
        } else {
            win.waitingFor = null;
            next.open = true;
        }
    }

    property Sheet waitingFor: null
    property Sheet toOpen: null
    Connections {
        target: win.waitingFor
        function onPChanged() {
            if (win.waitingFor && win.waitingFor.p < 0.3) {
                const s = win.toOpen;
                win.waitingFor = null;
                if (s && win.wanted !== "") s.open = true;
            }
        }
    }

    function dropFile(name: string): url {
        switch (name) {
        case "control": return Qt.resolvedUrl("drops/ControlDrop.qml");
        case "dashboard": return Qt.resolvedUrl("drops/DashboardDrop.qml");
        case "player": return Qt.resolvedUrl("drops/PlayerDrop.qml");
        case "launcher": return Qt.resolvedUrl("drops/LauncherDrop.qml");
        case "power": return Qt.resolvedUrl("drops/PowerDrop.qml");
        case "picker": return Qt.resolvedUrl("drops/PickerDrop.qml");
        case "overview": return Qt.resolvedUrl("drops/OverviewDrop.qml");
        case "network": return Qt.resolvedUrl("drops/NetworkDrop.qml");
        case "bluetooth": return Qt.resolvedUrl("drops/BluetoothDrop.qml");
        case "capture": return Qt.resolvedUrl("drops/CaptureDrop.qml");
        case "mixer": return Qt.resolvedUrl("drops/MixerDrop.qml");
        case "record": return Qt.resolvedUrl("drops/RecordDrop.qml");
        case "tray": return Qt.resolvedUrl("drops/TrayDrop.qml");
        default: return "";
        }
    }

    function clipFor(side: string): real {
        return side === "right" ? win.depth : Math.max(win.line, centreFill.value);
    }

    Pulses { id: pulses }

    function pulseAt(x: real, y: real, strength: real): void {
        if (Settings.bar.touchLight) pulses.emit(x, y, strength);
    }

    Connections {
        target: Beat
        function onBeat(strength) {
            if (win.tucked) return;
            const x = win.width * (0.08 + Math.random() * 0.84);
            pulses.emit(x, win.line + 2, 0.35 + strength * 0.55);
        }
    }

    Waterline {
        id: water
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: Math.min(win.height, Math.max(win.depth, sheetA.visibleBottom, sheetB.visibleBottom, toastSheet.visibleBottom) + 64)

        line: win.line * lift.value
        rimBase: 0.22 + Beat.glow * 0.55
        pool0: Qt.vector4d(-60, leftEdge.value, win.depth * lift.value, 18)
        pool1: Qt.vector4d(win.width / 2 - centreWidth.value / 2, win.width / 2 + centreWidth.value / 2, centreFill.value * lift.value, 16)
        pool2: Qt.vector4d(rightEdge.value, win.width + 60, win.depth * lift.value, 18)
        visible: lift.value > 0.002 || win.anyOpen
        drop0: sheetA.shape
        drop1: sheetB.shape
        drop2: toastSheet.shape
        bend0: sheetA.bend
        bend1: sheetB.bend
        bend2: toastSheet.bend
        cursor: hover.hovered ? hover.point.position : Qt.point(-1, -1)
        ripple: Qt.vector4d(ripple.origin, ripple.progress, ripple.progress < 1 ? 0.9 : 0, 0)
        pulse0: pulses.p0
        pulse1: pulses.p1
        pulse2: pulses.p2
        pulse3: pulses.p3

        HoverHandler { id: hover }
        TapHandler {
            gesturePolicy: TapHandler.DragThreshold
            onPressedChanged: if (pressed) win.pulseAt(point.position.x, point.position.y, 0.8)
        }
    }

    QtObject {
        id: ripple
        property real origin: 0
        property real progress: 1
    }
    NumberAnimation {
        id: rippleRun
        target: ripple; property: "progress"; from: 0; to: 1
        duration: Motion.scaled(760)
        easing.type: Easing.OutCubic
    }
    Connections {
        target: spaces
        function onActiveIdChanged() {
            if (!Settings.bar.touchLight) return;
            ripple.origin = left.x + spaces.x + spaces.activeX;
            rippleRun.restart();
        }
    }

    Item {
        x: 0; y: 0
        width: leftEdge.value; height: win.depth
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                spaces.scroll(event.pixelDelta.y !== 0 ? event.pixelDelta.y * 4 : event.angleDelta.y);
            }
        }
    }

    Row {
        id: left
        x: win.gutter
        y: (win.depth + win.line) / 2 - 16 - (1 - lift.value) * win.depth
        opacity: Math.max(0, lift.value * 1.4 - 0.4)
        visible: opacity > 0
        height: 32
        spacing: 20

        Spaces {
            id: spaces
            monitor: win.monitor
            anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            width: 1; height: 14
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(Theme.line, 0.9)
            visible: title.visible && title.implicitWidth > 2
        }
        WindowTitle {
            id: title
            visible: Settings.bar.windowTitle && !win.centreOpen && maxWidth >= 80
            anchors.verticalCenter: parent.verticalCenter
            monitor: win.monitor
            // whatever is left between the workspaces and the middle pool
            maxWidth: Math.max(0, Math.min(520, (centre.present ? centre.x : win.width / 2) - 56 - left.x - spaces.width - 41))
            TapHandler { onTapped: Panels.toggle("overview") }
        }
    }

    CentrePool {
        id: centre
        x: Math.round(win.width / 2 - this.implicitWidth / 2)
        height: centre.depth > 0 ? centre.depth - 12 : 30
        y: (centreFill.value + win.line) / 2 - height / 2 - (1 - lift.value) * win.depth
        width: this.implicitWidth
        opacity: centreFill.value > win.centreDepth * 0.6 && lift.value > 0.6 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.quick } }
    }

    Status {
        id: status
        x: win.width - win.gutter - this.implicitWidth
        y: (win.depth + win.line) / 2 - 16 - (1 - lift.value) * win.depth
        opacity: Math.max(0, lift.value * 1.4 - 0.4)
        visible: opacity > 0
    }

    Sheet {
        id: sheetA
        host: win
        anchors.fill: parent
        clipTop: win.clipFor(sheetA.side)
        fallback: Qt.resolvedUrl("drops/FailedDrop.qml")
        focus: win.useA
        onFailedSourceChanged: win.failed = win.wanted
    }
    Sheet {
        id: sheetB
        host: win
        anchors.fill: parent
        clipTop: win.clipFor(sheetB.side)
        fallback: Qt.resolvedUrl("drops/FailedDrop.qml")
        focus: !win.useA
        onFailedSourceChanged: win.failed = win.wanted
    }

    // toasts wait (timers paused) while a panel is out
    Sheet {
        id: toastSheet
        host: win
        anchors.fill: parent
        side: "right"
        clipTop: win.depth
        open: win.hosting && !win.anyOpen && !sheetA.active && !sheetB.active
              && toastSheet.item !== null && toastSheet.item.count > 0
        sourceComponent: Component { ToastStack {} }
    }

    Item { id: hitLeft; x: 0; y: 0; width: leftEdge.value; height: win.depth * lift.value }
    Item { id: hitCentre; x: win.width / 2 - centreWidth.value / 2; y: 0; width: centreWidth.value; height: centreFill.value * lift.value }
    Item { id: hitRight; x: rightEdge.value; y: 0; width: win.width - rightEdge.value; height: win.depth * lift.value }
    // when tucked away, the top two pixels bring it back
    Item {
        id: hitPeek
        width: win.width
        height: win.fullscreenHere ? 2 : 0
        HoverHandler {
            onHoveredChanged: if (this.hovered) { peekLeave.stop(); win.peeking = true; }
        }
    }
    Connections {
        target: hover
        function onHoveredChanged() {
            if (!win.fullscreenHere) return;
            if (hover.hovered) peekLeave.stop(); else if (win.peeking) peekLeave.restart();
        }
    }
    Item { id: hitA; x: sheetA.shape.x; y: 0; width: sheetA.active ? sheetA.shape.z : 0; height: sheetA.visibleBottom }
    Item { id: hitB; x: sheetB.shape.x; y: 0; width: sheetB.active ? sheetB.shape.z : 0; height: sheetB.visibleBottom }
    Item { id: hitToasts; x: toastSheet.shape.x; y: 0; width: toastSheet.active ? toastSheet.shape.z : 0; height: toastSheet.visibleBottom }

    mask: Region {
        Region { item: hitLeft }
        Region { item: hitCentre }
        Region { item: hitRight }
        Region { item: hitPeek }
        Region { item: hitA }
        Region { item: hitB }
        Region { item: hitToasts }
    }

    // music players don't inhibit idle themselves, so without the second half you get
    // locked out mid-album
    IdleInhibitor {
        window: win
        enabled: Settings.idle.caffeine || (Settings.idle.awakeForMusic && Players.playing)
    }

    HyprlandFocusGrab {
        active: win.hosting && Panels.isOpen
        windows: [win]
        onCleared: Panels.close()
    }
}
