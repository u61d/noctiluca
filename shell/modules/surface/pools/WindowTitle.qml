import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import qs.core
import qs.components

// a terminal retitling itself on every command only gets a crossfade, not the sweep
Item {
    id: root

    property int maxWidth: 420
    property var monitor: null

    // not `top`: Item's anchor lines are FINAL.
    // hyprland keeps the last window as active when you go to an empty workspace, so only show
    // it if it's on the workspace this screen is showing
    readonly property var activeWindow: {
        const w = Hyprland.activeToplevel;
        if (!w) return null;
        const here = root.monitor ? root.monitor.activeWorkspace : null;
        if (here && w.workspace && w.workspace.id !== here.id) return null;
        return w;
    }
    readonly property string appName: {
        const w = root.activeWindow && root.activeWindow.wayland ? root.activeWindow.wayland : null;
        return w && w.appId ? w.appId : "";
    }
    readonly property string titleText: root.activeWindow && root.activeWindow.title ? root.activeWindow.title : ""

    readonly property string label: {
        if (root.appName === "" && root.titleText === "") return "";
        if (root.appName === "") return root.titleText;
        if (root.titleText === "" || root.titleText === root.appName) return root.appName;
        return root.appName + "  —  " + root.titleText;
    }

    property string shown: ""
    property string outgoing: ""
    property string shownApp: ""

    implicitWidth: Math.min(Math.max(current.implicitWidth, 1), root.maxWidth)
    implicitHeight: 36
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: Motion.smooth; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.glide }
    }

    onLabelChanged: {
        const appChanged = root.appName !== root.shownApp;
        root.outgoing = root.shown;
        root.shown = root.label;
        root.shownApp = root.appName;
        if (root.label === "") {
            sweep.stop();
            exchange.stop();
            reveal.amount = 1;
            reveal.outAlpha = 0;
            return;
        }
        if (appChanged) {
            exchange.stop();
            revealClip.opacity = 1;
            sweep.restart();
        } else {
            // a stopped sweep would leave the old title half visible under the new one
            sweep.stop();
            reveal.amount = 1;
            reveal.outAlpha = 0;
            exchange.restart();
        }
    }

    QtObject {
        id: reveal
        property real amount: 1      // 0 = nothing revealed, 1 = fully revealed
        property real outAlpha: 0    // opacity of the outgoing title
        property real outLift: 0     // how far the outgoing title has lifted away
    }

    TypeText {
        anchors.verticalCenter: parent.verticalCenter
        role: "body"
        color: Theme.mute
        text: root.outgoing
        width: root.maxWidth
        elide: Text.ElideRight
        visible: reveal.outAlpha > 0.01
        opacity: reveal.outAlpha
        transform: Translate { y: -4 * reveal.outLift }
    }

    Item {
        id: revealClip
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: root.width * reveal.amount
        clip: true

        TypeText {
            id: current
            anchors.verticalCenter: parent.verticalCenter
            role: "body"
            color: Theme.dim
            text: root.shown
            elide: Text.ElideRight
            width: root.maxWidth
        }
    }

    Item {
        id: sweepLine
        x: revealClip.width
        width: 1
        height: parent.height
        visible: sweep.running

        Shape {
            x: -22
            width: 22
            height: parent.height
            asynchronous: false
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 22; y2: 0
                    GradientStop { position: 0.0; color: Qt.alpha(Theme.glow, 0.0) }
                    GradientStop { position: 1.0; color: Qt.alpha(Theme.glow, 0.26) }
                }
                PathSvg { path: "M 0 0 H 22 V " + sweepLine.height + " H 0 Z" }
            }
        }

        Rectangle {
            width: 1
            height: parent.height
            color: Theme.glow
            opacity: 0.9
        }
    }

    ParallelAnimation {
        id: sweep
        NumberAnimation {
            target: reveal; property: "amount"; from: 0; to: 1
            duration: Motion.smooth; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.glide
        }
        NumberAnimation {
            target: reveal; property: "outAlpha"; from: 0.8; to: 0
            duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.exit
        }
        NumberAnimation {
            target: reveal; property: "outLift"; from: 0; to: 1
            duration: Motion.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.exit
        }
    }

    SequentialAnimation {
        id: exchange
        NumberAnimation {
            target: revealClip; property: "opacity"; to: 0.35
            duration: Motion.tick; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.exit
        }
        NumberAnimation {
            target: revealClip; property: "opacity"; to: 1
            duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle
        }
    }

    Component.onCompleted: {
        root.shown = root.label;
        root.shownApp = root.appName;
        reveal.amount = 1;
    }
}
