import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services

// its own strip window so the plankton only repaints that strip
PanelWindow {
    id: win

    required property var modelData
    screen: win.modelData

    WlrLayershell.namespace: Tokens.nsDesktop
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    implicitHeight: 330
    color: "transparent"
    visible: Settings.desktop.clock || Settings.desktop.plankton

    mask: Region {}

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        id: clockColumn
        x: Settings.desktop.clockCorner === "right" ? win.width - 96 - clockColumn.width : 96
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 96
        spacing: 0
        visible: Settings.desktop.clock

        Text {
            anchors.right: Settings.desktop.clockCorner === "right" ? parent.right : undefined
            text: Qt.formatDateTime(clock.date, "dddd") + ", week " + weeks.isoWeek(clock.date)
            font.family: Tokens.fontSans; font.pixelSize: 12; font.weight: Font.Medium
            renderType: Text.NativeRendering
            color: Qt.alpha(Theme.glow, 0.75)
            Behavior on color { ColorAnimation { duration: Motion.drift } }
        }
        Text {
            anchors.right: Settings.desktop.clockCorner === "right" ? parent.right : undefined
            text: Qt.formatDateTime(clock.date, Settings.timeFormat)
            font.family: Tokens.fontSans; font.weight: Font.ExtraLight; font.pixelSize: 176
            font.letterSpacing: -6
            lineHeight: 0.86
            color: Qt.alpha(Theme.text, 0.94)
        }
        Row {
            anchors.right: Settings.desktop.clockCorner === "right" ? parent.right : undefined
            spacing: 18
            layoutDirection: Settings.desktop.clockCorner === "right" ? Qt.RightToLeft : Qt.LeftToRight
            Text {
                text: Qt.formatDateTime(clock.date, "d MMMM")
                font.family: Tokens.fontSans; font.weight: Font.Light; font.pixelSize: 26
                color: Qt.alpha(Theme.text, 0.70)
            }
            Rectangle {
                width: 1; height: 22
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(Theme.text, 0.25)
                visible: playing.visible
            }
            Text {
                id: playing
                anchors.verticalCenter: parent.verticalCenter
                visible: Players.playing && Players.title !== ""
                text: Players.title + (Players.artist ? " by " + Players.artist : "")
                width: Math.min(this.implicitWidth, 520)
                elide: Text.ElideRight
                font.family: Tokens.fontMono; font.pixelSize: 13
                renderType: Text.NativeRendering
                color: Qt.alpha(Theme.text, 0.48)
            }
        }
    }

    readonly property bool wantsCava: Settings.desktop.plankton && Players.playing
    onWantsCavaChanged: wantsCava ? Cava.want("plankton") : Cava.drop("plankton")
    Component.onCompleted: if (wantsCava) Cava.want("plankton")

    Item {
        id: plankton
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 80
        visible: Settings.desktop.plankton
        readonly property bool hasSignal: plankton.levels.some(function(v) { return v > 0.02; })
        opacity: Players.playing && plankton.hasSignal ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }

        readonly property int count: 128
        readonly property var levels: Cava.levels

        Repeater {
            model: plankton.count
            delegate: Rectangle {
                id: mote
                required property int index
                readonly property real level: {
                    const lv = plankton.levels;
                    const n = lv.length;
                    if (n === 0) return 0;
                    const f = mote.index / plankton.count * (n - 1);
                    const i = Math.floor(f);
                    const a = lv[i] || 0, b = lv[Math.min(n - 1, i + 1)] || 0;
                    return a + (b - a) * (f - i);
                }
                readonly property real phase: (mote.index * 37 % 11) / 11      // fixed, per mote

                x: 14 + mote.index * (win.width - 28) / plankton.count
                readonly property real gain: Math.min(1.4, mote.level * Settings.desktop.planktonGain)
                y: plankton.height - 14 - mote.gain * 50 - mote.phase * 4
                width: 2 + mote.gain * 3
                height: this.width
                radius: this.width / 2
                color: Theme.glow
                opacity: Math.min(1, 0.16 + mote.gain * 0.8)
            }
        }
    }

    QtObject {
        id: weeks
        function isoWeek(d): int {
            const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
            const day = t.getUTCDay() || 7;
            t.setUTCDate(t.getUTCDate() + 4 - day);
            const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
            return Math.ceil(((t - y0) / 86400000 + 1) / 7);
        }
    }
}
