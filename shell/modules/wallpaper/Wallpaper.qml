import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services

// decoded at screen size: a 6000x4000 photo at full size is ~96 MB per slot.
// the tide shader only exists during a transition
PanelWindow {
    id: win

    required property var modelData
    screen: win.modelData

    WlrLayershell.namespace: Tokens.nsBackground
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    // a zone of 0 would push the image below the bar's strip
    exclusionMode: ExclusionMode.Ignore
    color: Theme.surfaceVoid

    readonly property string shown: Wallpapers.shown

    property bool aIsCurrent: true
    readonly property Image current: win.aIsCurrent ? imgA : imgB
    readonly property Image incoming: win.aIsCurrent ? imgB : imgA
    property real progress: 1
    readonly property bool transitioning: win.progress < 1

    onShownChanged: win.load()
    Component.onCompleted: {
        if (win.shown !== "") imgA.source = Paths.fileUrl(win.shown);   // first paint: no transition
    }

    function load(): void {
        if (win.shown === "") {
            imgA.source = "";
            imgB.source = "";
            return;
        }
        const url = Paths.fileUrl(win.shown);
        if (win.current.source == url && win.current.status === Image.Ready) return;
        win.incoming.source = url;            // decoded off-thread; begin() runs when it is Ready
    }

    function begin(): void {
        tide.stop();
        win.progress = 0;
        tide.start();
    }

    NumberAnimation {
        id: tide
        target: win; property: "progress"
        from: 0; to: 1
        duration: (Settings.wallpaper.transition === "tide") ? Math.round(Settings.wallpaper.tideSeconds * 1000) : Motion.drift
        easing.type: Easing.InOutCubic
        onFinished: {
            win.aIsCurrent = !win.aIsCurrent;
            // don't keep the old one decoded (~33 MB per screen at 4k)
            win.incoming.source = "";
        }
    }

    // decode at real pixels, not logical ones, or a scaled screen gets a blurry wallpaper
    readonly property real dpr: win.screen && win.screen.devicePixelRatio > 0 ? win.screen.devicePixelRatio : 1

    component Slot: Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
    }

    Slot {
        id: imgA
        sourceSize.width: Math.ceil(win.width * win.dpr)
        sourceSize.height: Math.ceil(win.height * win.dpr)
        visible: !win.transitioning && win.aIsCurrent && this.status === Image.Ready
        onStatusChanged: if (this.status === Image.Ready && !win.aIsCurrent) win.begin()
    }
    Slot {
        id: imgB
        sourceSize.width: Math.ceil(win.width * win.dpr)
        sourceSize.height: Math.ceil(win.height * win.dpr)
        visible: !win.transitioning && !win.aIsCurrent && this.status === Image.Ready
        onStatusChanged: if (this.status === Image.Ready && win.aIsCurrent) win.begin()
    }

    Loader {
        anchors.fill: parent
        active: win.transitioning && (Settings.wallpaper.transition === "tide")
        sourceComponent: ShaderEffect {
            property size size: Qt.size(this.width, this.height)
            property real progress: win.progress
            property variant fromTex: win.current
            property variant toTex: win.incoming
            property real fromAspect: win.current.status === Image.Ready && win.current.implicitHeight > 0
                                      ? win.current.implicitWidth / win.current.implicitHeight : 0
            property real toAspect: win.incoming.implicitHeight > 0
                                    ? win.incoming.implicitWidth / win.incoming.implicitHeight : 0
            property color glow: Theme.glow
            property color base: Theme.surfaceVoid
            fragmentShader: Qt.resolvedUrl("../../shaders/tide.frag.qsb")
        }
    }

    Image {
        anchors.fill: parent
        visible: win.transitioning && !(Settings.wallpaper.transition === "tide")
        source: win.current.source
        sourceSize: win.current.sourceSize
        fillMode: Image.PreserveAspectCrop
        opacity: 1 - win.progress
    }
    Image {
        anchors.fill: parent
        visible: win.transitioning && !(Settings.wallpaper.transition === "tide")
        source: win.incoming.source
        sourceSize: win.incoming.sourceSize
        fillMode: Image.PreserveAspectCrop
        opacity: win.progress
    }

    // keeps the bar's rim readable over bright photos
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 140
        visible: imgA.status === Image.Ready || imgB.status === Image.Ready
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.surfaceVoid, 0.45) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
