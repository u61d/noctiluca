import QtQuick
import qs.core

Item {
    id: rc
    property string ch: ""
    property string was: ""
    property real p: 1
    property int size: 196
    property int weight: Font.ExtraLight

    implicitWidth: now.implicitWidth
    implicitHeight: now.implicitHeight
    Behavior on implicitWidth { NumberAnimation { duration: Motion.base } }
    clip: false

    onChChanged: {
        if (rc.was === "") { rc.was = rc.ch; return; }
        roll.stop();
        rc.p = 0;
        roll.start();
    }
    NumberAnimation {
        id: roll
        target: rc; property: "p"; from: 0; to: 1
        duration: Motion.reduced ? 0 : Motion.slow
        easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle
        onFinished: rc.was = rc.ch
    }

    Text {
        id: before
        text: rc.was
        visible: rc.p < 1
        y: -rc.height * 0.32 * rc.p
        opacity: 1 - rc.p
        font: now.font
        color: now.color
    }
    Text {
        id: now
        text: rc.ch
        y: rc.height * 0.32 * (1 - rc.p)
        opacity: rc.p
        font.family: Tokens.fontSans
        font.weight: rc.weight
        font.pixelSize: rc.size
        color: Qt.alpha(Theme.text, 0.96)
    }
}
