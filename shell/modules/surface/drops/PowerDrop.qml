import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.core
import qs.components
import qs.services

// lock and suspend go on the first press. the four that lose work arm first and need a second
// press on the same tile within 5s. moving the selection disarms, so holding enter can't walk
// through it. letters l s h e r p jump to a tile.
Item {
    id: root

    property var host: null

    readonly property int columns: 3
    readonly property real gap: 10
    readonly property real tileW: Math.floor((root.implicitWidth - root.gap * (root.columns - 1)) / root.columns)
    readonly property real tileH: 112

    implicitWidth: 432
    implicitHeight: head.height + 22 + 2 * root.tileH + root.gap + 34

    readonly property var actions: [
        { name: "Lock",      verb: "lock",      icon: Icons.lock,      key: Qt.Key_L, safe: true  },
        { name: "Suspend",   verb: "suspend",   icon: Icons.suspend,   key: Qt.Key_S, safe: true  },
        { name: "Hibernate", verb: "hibernate", icon: Icons.hibernate, key: Qt.Key_H, safe: false },
        { name: "Log out",   verb: "log out",   icon: Icons.logout,    key: Qt.Key_E, safe: false },
        { name: "Restart",   verb: "restart",   icon: Icons.reboot,    key: Qt.Key_R, safe: false },
        { name: "Shut down", verb: "shut down", icon: Icons.power,     key: Qt.Key_P, safe: false }
    ]

    property int selected: 0
    property int armed: -1
    onSelectedChanged: root.armed = -1          // the armed tile is always the selected one

    function takeFocus(): void { keys.forceActiveFocus(); }

    Component.onCompleted: Session.wantUptime = true
    Component.onDestruction: Session.wantUptime = false

    function run(i: int): void {
        const a = root.actions[i];
        if (!a) return;
        if (!a.safe && root.armed !== i) {
            root.armed = i;
            disarm.restart();
            return;
        }
        root.armed = -1;
        Panels.close();                          // get out of the way first
        switch (a.name) {
        case "Lock": Session.lock(); break;
        case "Suspend": Session.suspend(); break;
        case "Hibernate": Session.hibernate(); break;
        case "Log out": Session.logout(); break;
        case "Restart": Session.reboot(); break;
        case "Shut down": Session.shutdown(); break;
        }
    }

    Timer {
        id: disarm
        interval: 5000
        onTriggered: root.armed = -1
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
            const n = root.actions.length, c = root.columns;
            if (event.key === Qt.Key_Escape) {
                if (root.armed >= 0) root.armed = -1;      // the first Escape only disarms
                else Panels.close();
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                root.selected = (root.selected + 1) % n;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                root.selected = (root.selected + n - 1) % n;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                root.selected = (root.selected + c) % n;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                root.selected = (root.selected + n - c) % n;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.run(root.selected);
            } else {
                for (let i = 0; i < n; i++) {
                    if (root.actions[i].key === event.key) {
                        // a letter acts on its tile, `p` once still isn't a shutdown
                        root.selected = i;
                        root.run(i);
                        event.accepted = true;
                        return;
                    }
                }
                event.accepted = false;
                return;
            }
            event.accepted = true;
        }
    }

    Item {
        id: head
        width: parent.width
        height: 46

        Item {
            id: face
            width: 0; height: 1
        }
        Column {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: 3
            Text {
                text: Session.username
                font.family: Tokens.fontSans; font.pixelSize: 17; font.weight: Font.Medium
                renderType: Text.NativeRendering
                color: Theme.text
            }
            Text {
                text: Session.uptime !== "" ? "Up " + Session.uptime.replace(/^up\s+/, "") : ""
                font.family: Tokens.fontSans; font.pixelSize: 13
                renderType: Text.NativeRendering
                color: Theme.mute
            }
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 6
            visible: Battery.present
            Icon { anchors.verticalCenter: parent.verticalCenter; path: Battery.icon; size: 16; color: Battery.percent <= 15 && !Battery.charging ? Theme.alert : Theme.glow }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.percent + "%"
                font.family: Tokens.fontMono; font.pixelSize: 12
                renderType: Text.NativeRendering
                color: Theme.dim
            }
        }
    }

    Grid {
        id: grid
        y: head.height + 22
        columns: root.columns
        spacing: root.gap

        Repeater {
            model: root.actions

            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool isSel: root.selected === tile.index
                readonly property bool isArmed: root.armed === tile.index
                readonly property color tint: tile.isArmed ? Theme.alert : Theme.glow

                width: root.tileW
                height: root.tileH

                Rectangle {
                    id: face2
                    anchors.fill: parent
                    radius: 18
                    color: tile.isArmed ? Qt.alpha(Theme.alert, 0.12)
                         : tile.isSel ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(1, 1, 1, 0.03)
                    Behavior on color { ColorAnimation { duration: Motion.quick } }
                }

                Shape {
                    anchors.fill: parent
                    visible: tile.isArmed
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.alert
                        strokeWidth: 1.5
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        // rounded rect drawn from the top middle, as far as `left` says
                        PathSvg {
                            readonly property real w: tile.width - 1
                            readonly property real h: tile.height - 1
                            readonly property real r: 17.5
                            path: "M " + (w / 2 + 0.5) + " 0.5 H " + (w - r) + " A " + r + " " + r + " 0 0 1 " + (w + 0.5) + " " + (r + 0.5)
                                  + " V " + (h - r) + " A " + r + " " + r + " 0 0 1 " + (w - r) + " " + (h + 0.5)
                                  + " H " + (r + 0.5) + " A " + r + " " + r + " 0 0 1 0.5 " + (h - r)
                                  + " V " + (r + 0.5) + " A " + r + " " + r + " 0 0 1 " + (r + 0.5) + " 0.5 Z"
                        }
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [countdown.left * 330, 400]
                    }
                }
                QtObject { id: countdown; property real left: 1 }
                NumberAnimation {
                    target: countdown; property: "left"
                    from: 1; to: 0
                    duration: disarm.interval
                    running: tile.isArmed
                }

                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 4
                    spacing: 10
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        path: tile.modelData.icon
                        size: 22
                        color: tile.isArmed ? Theme.alert : tile.isSel ? Theme.glowHi : Theme.dim
                        Behavior on color { ColorAnimation { duration: Motion.quick } }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.isArmed ? "Press again" : tile.modelData.name
                        font.family: Tokens.fontSans; font.pixelSize: tile.isArmed ? 12 : 13; font.weight: Font.Medium
                        renderType: Text.NativeRendering
                        color: tile.isArmed ? Theme.alert : tile.isSel ? Theme.text : Theme.dim
                        Behavior on color { ColorAnimation { duration: Motion.quick } }
                    }
                }

                opacity: 0
                transform: Translate { id: slide; y: 10 }
                Component.onCompleted: arrive.start()
                SequentialAnimation {
                    id: arrive
                    PauseAnimation { duration: Motion.stagger(tile.index) + 60 }
                    ParallelAnimation {
                        NumberAnimation { target: tile; property: "opacity"; to: 1; duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
                        NumberAnimation { target: slide; property: "y"; to: 0; duration: Motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (this.hovered) root.selected = tile.index
                }
                TapHandler {
                    onTapped: {
                        root.selected = tile.index;
                        root.run(tile.index);
                    }
                }
            }
        }
    }

    Text {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        visible: root.armed >= 0
        text: "Esc cancels"
        font.family: Tokens.fontMono; font.pixelSize: 10
        renderType: Text.NativeRendering
        color: Qt.alpha(Theme.mute, 0.85)
    }
}
