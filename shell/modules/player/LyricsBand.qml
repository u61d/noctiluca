import QtQuick
import qs.core
import qs.components
import qs.services

Item {
    id: root

    property color accent: Players.accent

    implicitHeight: 118
    clip: true

    function lineAt(i: int): string {
        return i >= 0 && i < Lyrics.lines.length ? Lyrics.lines[i].text : "";
    }

    readonly property int at: Lyrics.index
    property real slide: 0
    onAtChanged: { slideIn.stop(); root.slide = 1; slideIn.start(); }
    NumberAnimation {
        id: slideIn
        target: root; property: "slide"; to: 0
        duration: Motion.smooth
        easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle
    }

    Column {
        visible: Lyrics.synced
        width: parent.width
        y: (root.height - height) / 2 + root.slide * 30
        spacing: 6

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.lineAt(root.at - 1)
            elide: Text.ElideRight
            font.family: Tokens.fontSans; font.pixelSize: 14
            renderType: Text.NativeRendering
            color: Theme.mute
            opacity: 0.6
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.at >= 0 ? root.lineAt(root.at) : "♪"
            elide: Text.ElideRight
            font.family: Tokens.fontSans; font.pixelSize: 22; font.weight: Font.Medium
            renderType: Text.NativeRendering
            color: Theme.text
            opacity: 1 - root.slide * 0.6
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.lineAt(root.at + 1)
            elide: Text.ElideRight
            font.family: Tokens.fontSans; font.pixelSize: 15
            renderType: Text.NativeRendering
            color: Theme.dim
            opacity: 0.8
        }
    }

    Row {
        visible: !Lyrics.synced
        anchors.centerIn: parent
        spacing: 10
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            path: Icons.lyrics; size: 15
            color: Theme.mute
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Lyrics.state === "loading" ? "looking for lyrics…"
                : Lyrics.instrumental ? "instrumental"
                : Lyrics.state === "error" ? "lyrics unavailable right now"
                : Lyrics.plain !== "" ? "lyrics found, but not time-synced"
                : "no synced lyrics for this track"
            font.family: Tokens.fontMono; font.pixelSize: 11; font.letterSpacing: 0.4
            renderType: Text.NativeRendering
            color: Theme.mute
        }
    }
}
