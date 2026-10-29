import QtQuick
import QtQuick.Effects
import Quickshell
import qs.core
import qs.components
import qs.services
import qs.modules.player

Item {
    id: root

    property var host: null

    readonly property bool lyrics: Settings.player.lyrics
    readonly property bool several: Players.all.length > 1

    implicitWidth: 720
    implicitHeight: Players.hasPlayer ? 268 + (root.lyrics ? 140 : 0) + (root.several ? 54 : 0) : 132

    function takeFocus(): void { keys.forceActiveFocus(); }

    // each panel asks under its own name so one that's still closing can't turn off the new one
    readonly property string me: "player-" + Math.random().toString(36).slice(2)
    readonly property bool wantsBars: Settings.player.visualizer
    onWantsBarsChanged: wantsBars ? Cava.want(root.me) : Cava.drop(root.me)
    Component.onCompleted: {
        Players.watchingClosely = true;
        if (root.wantsBars) Cava.want(root.me);
        Lyrics.want(root.me);
    }
    Component.onDestruction: {
        Players.watchingClosely = false;
        Cava.drop(root.me);
        Lyrics.drop(root.me);
    }

    function clock(seconds: real): string {
        if (!isFinite(seconds) || seconds <= 0) return "0:00";
        const t = Math.floor(seconds);
        const s = t % 60, m = Math.floor(t / 60) % 60, h = Math.floor(t / 3600);
        const ss = s < 10 ? "0" + s : "" + s;
        if (h > 0) return h + ":" + (m < 10 ? "0" + m : "" + m) + ":" + ss;
        return m + ":" + ss;
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
            switch (event.key) {
            case Qt.Key_Space: Players.playPause(); break;
            case Qt.Key_N: Players.next(); break;
            case Qt.Key_P: Players.previous(); break;
            case Qt.Key_S: Players.toggleShuffle(); break;
            case Qt.Key_R: Players.cycleLoop(); break;
            case Qt.Key_Right:
                if (Players.canSeek && Players.length > 0) Players.seekFraction((Players.position + 5) / Players.length);
                break;
            case Qt.Key_Left:
                if (Players.canSeek && Players.length > 0) Players.seekFraction((Players.position - 5) / Players.length);
                break;
            default:
                event.accepted = false;
                return;
            }
            event.accepted = true;
        }
    }

    Column {
        anchors.centerIn: parent
        visible: !Players.hasPlayer
        spacing: 12
        Node {
            anchors.horizontalCenter: parent.horizontalCenter
            core: 7; halo: 9
            color: Theme.glow
            breathing: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nothing is playing"
            font.family: Tokens.fontSans; font.pixelSize: 15; font.weight: Font.Medium
            renderType: Text.NativeRendering
            color: Theme.dim
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "start something in Spotify, a browser or mpv"
            font.family: Tokens.fontMono; font.pixelSize: 11
            renderType: Text.NativeRendering
            color: Theme.mute
        }
    }

    Image {
        id: art
        source: Players.artUrl
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 400; sourceSize.height: 400
        asynchronous: true
        visible: false
    }

    Item {
        id: disc
        visible: Players.hasPlayer
        width: 268; height: 268

        Ring {
            anchors.centerIn: parent
            radius: 104
            reach: 24
            visible: Settings.player.visualizer
            live: Players.playing
            color: Players.accent
        }

        Item {
            id: coverBox
            anchors.centerIn: parent
            width: 196; height: 196

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.surfaceSlate
            }
            MultiEffect {
                anchors.fill: parent
                source: art
                maskEnabled: true
                maskSource: discMask
                opacity: art.status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.smooth } }
            }
            Item {
                id: discMask
                anchors.fill: parent
                layer.enabled: true
                visible: false
                Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
            }
            Node {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                core: 9; halo: 12
                color: Players.accent
                breathing: Players.playing
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(Players.accentHi, 0.45)
                Behavior on border.color { ColorAnimation { duration: Motion.drift } }
            }
        }
    }

    Item {
        id: side
        visible: Players.hasPlayer
        anchors { left: disc.right; leftMargin: 26; right: parent.right; top: parent.top; topMargin: 18 }
        height: 232

        Row {
            id: source
            spacing: 8
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                color: Players.playing ? Players.accent : Theme.mute
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (Players.playing ? "Playing" : "Paused") + (Players.identity ? " in " + Players.identity : "")
                font.family: Tokens.fontSans; font.pixelSize: 12; font.weight: Font.Medium
                renderType: Text.NativeRendering
                color: Players.playing ? Players.accent : Theme.mute
                Behavior on color { ColorAnimation { duration: Motion.drift } }
            }
        }

        // long titles wrap, then shrink, then elide, so they never hit the time bar
        Item {
            id: names
            anchors { left: parent.left; right: parent.right; top: source.bottom; topMargin: 12; bottom: below.top; bottomMargin: 14 }
            Text {
                id: title
                width: parent.width
                height: Math.max(0, parent.height - (meta.visible ? meta.implicitHeight + 6 : 0))
                verticalAlignment: Text.AlignTop
                text: Players.title !== "" ? Players.title : "Unknown track"
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
                fontSizeMode: Text.Fit
                minimumPixelSize: 17
                font.family: Tokens.fontSans; font.pixelSize: 28; font.weight: Font.Medium
                font.letterSpacing: -0.3
                lineHeight: 0.95
                renderType: Text.NativeRendering
                color: Theme.text
            }
            Column {
                id: meta
                visible: Players.artist !== "" || Players.album !== ""
                y: Math.min(title.contentHeight, title.height) + 6
                width: parent.width
                spacing: 3
                Text {
                    width: parent.width
                    text: Players.artist
                    visible: text !== ""
                    elide: Text.ElideRight
                    font.family: Tokens.fontSans; font.pixelSize: 16
                    renderType: Text.NativeRendering
                    color: Theme.dim
                }
                Text {
                    width: parent.width
                    text: Players.album
                    visible: text !== ""
                    elide: Text.ElideRight
                    font.family: Tokens.fontSans; font.pixelSize: 12
                    renderType: Text.NativeRendering
                    color: Theme.mute
                }
            }
        }

        Column {
            id: below
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            spacing: 8

            Scrubber { width: parent.width; accent: Players.accent }
            Item {
                width: parent.width; height: 14
                Text {
                    text: root.clock(Players.position)
                    font.family: Tokens.fontMono; font.pixelSize: 11
                    renderType: Text.NativeRendering
                    color: Theme.dim
                }
                Text {
                    anchors.right: parent.right
                    text: Players.length > 0 ? "-" + root.clock(Players.length - Players.position) : ""
                    font.family: Tokens.fontMono; font.pixelSize: 11
                    renderType: Text.NativeRendering
                    color: Theme.mute
                }
            }

            Item {
                width: parent.width; height: 60
                Row {
                    anchors.centerIn: parent
                    spacing: 16

                    component Ctl: Item {
                        id: ctl
                        property string icon: ""
                        property bool on: true
                        property bool lit: false
                        property bool big: false
                        property string badge: ""
                        signal hit()
                        width: ctl.big ? 58 : 40; height: width
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: ctl.on ? 1 : 0.3
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: ctl.big ? Qt.alpha(Players.accent, cth.hovered ? 0.3 : 0.2)
                                           : cth.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                            border.width: ctl.big ? 1 : 0
                            border.color: Qt.alpha(Players.accent, 0.55)
                            Behavior on color { ColorAnimation { duration: Motion.quick } }
                        }
                        Icon {
                            anchors.centerIn: parent
                            path: ctl.icon
                            size: ctl.big ? 22 : 17
                            color: ctl.big ? Players.accentHi : ctl.lit ? Players.accent : cth.hovered ? Theme.text : Theme.dim
                            Behavior on color { ColorAnimation { duration: Motion.quick } }
                        }
                        Rectangle {
                            visible: ctl.lit && !ctl.big
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height - 6
                            width: 4; height: 4; radius: 2
                            color: Players.accent
                        }
                        Text {
                            visible: ctl.badge !== ""
                            x: parent.width / 2 + 5; y: 6
                            text: ctl.badge
                            font.family: Tokens.fontMono; font.pixelSize: 9; font.weight: Font.Bold
                            renderType: Text.NativeRendering
                            color: Players.accent
                        }
                        HoverHandler { id: cth; cursorShape: ctl.on ? Qt.PointingHandCursor : Qt.ArrowCursor }
                        TapHandler { enabled: ctl.on; onTapped: ctl.hit() }
                    }

                    Ctl { icon: Icons.shuffle; on: Players.shuffleSupported; lit: Players.shuffle; onHit: Players.toggleShuffle() }
                    Ctl { icon: Icons.previous; on: Players.canGoPrevious; onHit: Players.previous() }
                    Ctl { icon: Players.playing ? Icons.pause : Icons.play; big: true; onHit: Players.playPause() }
                    Ctl { icon: Icons.next; on: Players.canGoNext; onHit: Players.next() }
                    Ctl { icon: Icons.repeat; on: Players.loopSupported; lit: Players.loop > 0; badge: Players.loop === 1 ? "1" : ""; onHit: Players.cycleLoop() }
                }
            }
        }
    }

    Item {
        id: lyricsBox
        visible: Players.hasPlayer && root.lyrics
        anchors { left: parent.left; right: parent.right; top: disc.bottom; topMargin: 14 }
        height: 126
        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Qt.alpha(Theme.surfaceVoid, 0.35)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.05)
        }
        LyricsBand {
            anchors.fill: parent
            anchors.margins: 4
            accent: Players.accent
        }
    }

    Row {
        visible: Players.hasPlayer && root.several
        anchors { left: parent.left; bottom: parent.bottom }
        spacing: 8
        Repeater {
            model: Players.all
            delegate: Item {
                id: chip
                required property var modelData
                readonly property bool isActive: chip.modelData === Players.active
                width: chipText.implicitWidth + 34; height: 32
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: chip.isActive ? Qt.alpha(Players.accent, 0.16) : chh.hovered ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1
                    border.color: chip.isActive ? Qt.alpha(Players.accent, 0.45) : Qt.rgba(1, 1, 1, 0.06)
                }
                Rectangle {
                    x: 13; anchors.verticalCenter: parent.verticalCenter
                    width: 5; height: 5; radius: 2.5
                    color: chip.modelData && chip.modelData.isPlaying ? Players.accent : Theme.mute
                }
                Text {
                    id: chipText
                    x: 24; anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData && chip.modelData.identity ? chip.modelData.identity : "player"
                    font.family: Tokens.fontSans; font.pixelSize: 12
                    font.weight: chip.isActive ? Font.Medium : Font.Normal
                    renderType: Text.NativeRendering
                    color: chip.isActive ? Theme.text : Theme.dim
                }
                HoverHandler { id: chh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Players.pick(chip.modelData) }
            }
        }
    }
}
