import QtQuick
import qs.core
import qs.components

// content is laid out once at its final size and slides out from behind the line, nothing
// gets stretched while it moves. the outline goes to the shader as `shape` and `bend`.
FocusScope {
    id: sheet

    property var host: null
    property string side: "right"           // "right" or "centre"
    property url source: ""
    property Component sourceComponent: null
    property bool open: false
    property real clipTop: 40               // content disappears behind the pool above this
    property url fallback: ""               // shown instead of a panel that fails to compile
    property url failedSource: ""

    readonly property var item: loader.item
    readonly property bool active: sheet.open || progress.value > 0.0005 || progress.moving
    readonly property bool failed: loader.status === Loader.Error

    readonly property real rise: host ? host.rise : 22
    readonly property real contentTop: host ? host.contentTop : 54
    readonly property real gutter: host ? host.gutter : 26
    readonly property real edge: host ? host.edge : 16
    readonly property real screenW: host ? host.width : 1920

    readonly property real wantW: loader.item ? loader.item.implicitWidth + sheet.gutter * 2 : 0
    readonly property real wantH: loader.item ? sheet.rise + sheet.contentTop + loader.item.implicitHeight + 26 : 0
    readonly property real wantX: sheet.side === "right" ? sheet.screenW - sheet.edge - sheet.wantW
                                                         : Math.round((sheet.screenW - sheet.wantW) / 2)

    Spring {
        id: progress
        kind: sheet.open ? "open" : "close"
        target: sheet.open && loader.item ? 1 : 0
        epsilon: 0.0008
        onAtRestChanged: if (atRest && !sheet.open) sheet.unloadIfClosed()
    }
    Spring { id: sx; kind: "morph" }
    Spring { id: sw; kind: "morph" }
    Spring { id: sh; kind: "morph" }

    // only a sheet that's already out springs between sizes
    function place(): void {
        if (!loader.item) return;
        if (progress.value < 0.02) {
            sx.snap(sheet.wantX);
            sw.snap(sheet.wantW);
            sh.snap(sheet.wantH);
        } else {
            sx.target = sheet.wantX;
            sw.target = sheet.wantW;
            sh.target = sheet.wantH;
        }
    }
    onWantWChanged: sheet.place()
    onWantHChanged: sheet.place()
    onWantXChanged: sheet.place()

    readonly property real p: progress.value
    readonly property real travel: sh.value
    readonly property real sheetTop: -sheet.rise - (1 - sheet.p) * sheet.travel
    readonly property vector4d shape: sheet.active && sw.value > 0
                                      ? Qt.vector4d(sx.value, sheet.sheetTop, sw.value, sh.value)
                                      : Qt.vector4d(0, 0, 0, 0)

    readonly property real edgeSpeed: Math.abs(progress.velocity * sheet.travel + sheet.p * sh.velocity)
    readonly property vector4d bend: Qt.vector4d(Math.min(18, sheet.edgeSpeed * 0.0055 * Motion.stretch),
                                                 Math.min(9, sheet.edgeSpeed * 0.0022 * Motion.stretch), 0, 0)

    readonly property real visibleBottom: Math.max(0, sheet.sheetTop + sheet.travel)

    property real swapOpacity: 1
    property url pendingSource: ""
    SequentialAnimation {
        id: swap
        NumberAnimation { target: sheet; property: "swapOpacity"; to: 0; duration: Math.round(Motion.quick * 0.6); easing.type: Easing.InQuad }
        ScriptAction { script: { loader.source = sheet.pendingSource; sheet.afterLoad(); } }
        NumberAnimation { target: sheet; property: "swapOpacity"; to: 1; duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
    }

    onSourceChanged: {
        if (sheet.sourceComponent) return;
        if (sheet.source.toString() === "") return;     // closing keeps the old content until it is gone
        if (loader.item && sheet.p > 0.3) {
            sheet.pendingSource = sheet.source;
            swap.restart();
        } else {
            swap.stop();
            sheet.swapOpacity = 1;
            loader.source = sheet.source;
            sheet.afterLoad();
        }
    }

    function afterLoad(): void {
        sheet.place();
        if (sheet.open && loader.item && loader.item.takeFocus)
            loader.item.takeFocus();
    }

    function unloadIfClosed(): void {
        if (sheet.open || sheet.sourceComponent) return;
        loader.source = "";
        // collect garbage now while nothing moves, not during the next animation
        collect.restart();
    }
    Timer { id: collect; interval: 400; onTriggered: if (!sheet.active) gc() }

    onOpenChanged: {
        if (sheet.open) {
            if (!sheet.sourceComponent && loader.source.toString() !== sheet.source.toString() && sheet.source.toString() !== "") {
                swap.stop();
                sheet.swapOpacity = 1;
                loader.source = sheet.source;
            }
            sheet.afterLoad();
        }
    }

    Item {
        id: clipper
        x: Math.max(0, sx.value + 8)
        y: sheet.clipTop
        width: Math.max(0, sw.value - 16)
        height: (sheet.host ? sheet.host.height : 1080) - sheet.clipTop
        clip: true
        visible: sheet.active

        FocusScope {
            id: scope
            x: sheet.wantX + sheet.gutter - clipper.x
            y: sheet.contentTop + sheet.sheetTop + sheet.rise - sheet.clipTop
            width: Math.max(0, sheet.wantW - sheet.gutter * 2)
            height: loader.item ? loader.item.implicitHeight : 0
            focus: true
            opacity: sheet.swapOpacity * Math.max(0, Math.min(1, (sheet.p - 0.12) / 0.55))

            Keys.onEscapePressed: Panels.close()

            Loader {
                id: loader
                anchors.fill: parent
                focus: true
                sourceComponent: sheet.sourceComponent
                onLoaded: if (loader.item && "host" in loader.item) loader.item.host = sheet.host
                onStatusChanged: {
                    if (loader.status === Loader.Error && sheet.fallback.toString() !== "") {
                        console.warn("noctiluca: a panel failed to load; see the errors above");
                        sheet.failedSource = loader.source;
                        loader.source = sheet.fallback;
                        sheet.afterLoad();
                    }
                }
            }
        }
    }
}
