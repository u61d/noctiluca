import QtQuick
import QtQuick.Effects
import QtQuick.Particles
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services

// safety:
// - if this process dies the compositor keeps the screen locked and a restarted shell takes
//   the lock back (misc.allow_session_lock_restore)
// - the password only goes to pam, only once every screen is covered (`secure`), and is
//   cleared after each attempt
// - the lock is released in exactly one place, after pam says yes
Scope {
    id: scope

    GlobalShortcut {
        appid: Tokens.appId
        name: "lock"
        description: "Noctiluca: lock the screen"
        onPressed: Session.lock()
    }

    // design/previews reads this for the typed/failed states
    readonly property alias state: auth

    QtObject {
        id: auth
        property string entered: ""
        property bool busy: false
        property bool failed: false
        property bool unlocking: false
        property string message: ""
        property bool capsLock: false

        readonly property string hint: !lock.secure ? "securing the session…"
            : auth.busy ? "checking…"
            : auth.failed ? (auth.message !== "" ? auth.message : "wrong password")
            : auth.capsLock ? "caps lock is on"
            : "type your password"

        function submit(): void {
            if (auth.entered === "" || auth.busy || !lock.secure || auth.unlocking)
                return;
            auth.busy = true;
            auth.failed = false;
            // the password goes over in onPamMessage when pam asks for it
            if (!pam.start()) {
                auth.busy = false;
                auth.failed = true;
                auth.message = "could not start PAM";
                auth.entered = "";
            }
        }

        function key(event: var): void {
            if (auth.busy || !lock.secure || auth.unlocking) {
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Backspace) {
                auth.entered = (event.modifiers & Qt.ControlModifier) ? "" : auth.entered.slice(0, -1);
                auth.failed = false;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                auth.submit();
            } else if (event.key === Qt.Key_Escape) {
                auth.entered = "";
                auth.failed = false;
            } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 0x20) {
                auth.entered += event.text;
                auth.failed = false;
                auth.typed();
            }
            caps.running = true;
            event.accepted = true;
        }

        signal typed()
        signal rejected()
    }

    PamContext {
        id: pam
        config: "noctiluca"
        configDirectory: Quickshell.shellDir + "/pam"
        user: Session.username

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(auth.entered);
        }

        onCompleted: function(result) {
            auth.busy = false;
            auth.entered = "";
            if (result === PamResult.Success) {
                auth.failed = false;
                auth.message = "";
                auth.unlocking = true;          // the ink draws back, then the session opens
                release.restart();
                return;
            }
            auth.failed = true;
            auth.message = result === PamResult.MaxTries ? "too many attempts"
                         : result === PamResult.Error ? "authentication error"
                         : "wrong password";
            auth.rejected();
        }

        onError: function(error) {
            auth.busy = false;
            auth.entered = "";
            auth.failed = true;
            auth.message = error === PamError.StartFailed
                ? "PAM config missing (" + pam.configDirectory + "/" + pam.config + ")"
                : "PAM error";
            auth.rejected();
        }
    }

    // the only place the lock gets released
    Timer {
        id: release
        interval: Motion.reduced ? 0 : 380
        onTriggered: {
            Session.lockRequested = false;
            auth.unlocking = false;
        }
    }

    // hyprland sends nothing for caps lock, so read the led after a key press
    Process {
        id: caps
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -r | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: auth.capsLock = this.text.trim() !== "" && this.text.trim() !== "0"
        }
    }

    property bool counted: false
    property date lockedAt: new Date()
    Connections {
        target: Session
        function onLockRequestedChanged() {
            if (Session.lockRequested) scope.lockedAt = new Date();
            const want = Session.lockRequested && Settings.lock.weather;
            if (want && !scope.counted) { Weather.watchers++; scope.counted = true; }
            if (!want && scope.counted) { Weather.watchers = Math.max(0, Weather.watchers - 1); scope.counted = false; }
            if (Session.lockRequested) caps.running = true;
        }
    }

    WlSessionLock {
        id: lock
        locked: Session.lockRequested

        WlSessionLockSurface {
            id: surface
            color: Theme.surfaceVoid

            Image {
                id: wall
                anchors.fill: parent
                source: Paths.fileUrl(Wallpapers.current)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: Math.ceil(surface.width * (surface.screen ? surface.screen.devicePixelRatio || 1 : 1))
                sourceSize.height: Math.ceil(surface.height * (surface.screen ? surface.screen.devicePixelRatio || 1 : 1))
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: wall
                visible: wall.status === Image.Ready
                blurEnabled: Settings.lock.blur
                blur: tide.value
                blurMax: 56
                brightness: -0.16 * tide.value
                saturation: -0.25 * tide.value
                scale: 1 + 0.035 * tide.value
            }

            Spring {
                id: tide
                kind: auth.unlocking ? "close" : "open"
                target: auth.unlocking ? 0 : 1
                epsilon: 0.0008
            }
            function rise(): void {
                tide.snap(0);
                surface.intro = 0;
                introRun.restart();
                tide.target = Qt.binding(function() { return auth.unlocking ? 0 : 1; });
                keys.forceActiveFocus();
            }
            Component.onCompleted: surface.rise()
            Connections {
                target: Session
                function onLockRequestedChanged() { if (Session.lockRequested) surface.rise(); }
            }

            readonly property real sheetH: surface.height + 60
            readonly property real sheetTop: -22 - (1 - tide.value) * surface.sheetH
            // coming in this runs on its own slower clock so the pieces arrive one by one
            property real intro: 0
            NumberAnimation {
                id: introRun
                target: surface; property: "intro"; from: 0; to: 1
                duration: Motion.reduced ? 0 : Motion.scaled(1700)
                easing.type: Easing.OutCubic
            }
            readonly property real show: Math.min(surface.intro, Math.max(0, Math.min(1, (tide.value - 0.45) / 0.5)))
            function after(from: real, span: real): real {
                return Math.max(0, Math.min(1, (surface.show - from) / span));
            }

            Pulses { id: pulses }

            Waterline {
                anchors.fill: parent
                drop0: Qt.vector4d(-80, surface.sheetTop, surface.width + 160, surface.sheetH)
                bend0: Qt.vector4d(Math.min(28, Math.abs(tide.velocity * surface.sheetH) * 0.004 * Motion.stretch), 0, 0, 0)
                dropRadius: 40
                ink: Qt.alpha(Theme.surfaceVoid, 0.56)
                inkDeep: Qt.alpha(Qt.darker(Theme.surfaceVoid, 1.5), 0.82)
                glow: auth.failed ? Theme.alert : Theme.glow
                rimBase: 0.3
                pulse0: pulses.p0
                pulse1: pulses.p1
                pulse2: pulses.p2
                pulse3: pulses.p3
                Behavior on glow { ColorAnimation { duration: Motion.base } }
            }

            ParticleSystem {
                id: sea
                running: !Motion.reduced
            }
            ImageParticle {
                system: sea
                groups: ["drift", "spark"]
                source: "qrc:///particleresources/glowdot.png"
                color: Theme.glow
                colorVariation: 0.06
                alpha: 0.7
                alphaVariation: 0.3
                entryEffect: ImageParticle.Fade
                opacity: surface.show
            }
            ImageParticle {
                system: sea
                groups: ["alarm"]
                source: "qrc:///particleresources/glowdot.png"
                color: Theme.alert
                alpha: 0.7
                entryEffect: ImageParticle.Fade
            }
            Emitter {
                system: sea
                group: "drift"
                x: 0; y: surface.height * 0.3
                width: surface.width; height: surface.height * 0.7
                emitRate: Math.max(4, Math.round(surface.width / 150))
                lifeSpan: 12000; lifeSpanVariation: 4000
                // already drifting when the lock comes down
                startTime: 10000
                size: 15; sizeVariation: 11; endSize: 4
                velocity: AngleDirection { angle: 270; angleVariation: 20; magnitude: 11; magnitudeVariation: 8 }
            }
            Emitter {
                id: sparks
                system: sea
                group: "spark"
                enabled: false
                lifeSpan: 2600; lifeSpanVariation: 900
                size: 8; sizeVariation: 5; endSize: 1
                velocity: AngleDirection { angle: 270; angleVariation: 55; magnitude: 46; magnitudeVariation: 30 }
                acceleration: PointDirection { y: -6 }
            }
            Emitter {
                id: scatter
                system: sea
                group: "alarm"
                enabled: false
                lifeSpan: 1500; lifeSpanVariation: 500
                size: 9; sizeVariation: 4; endSize: 1
                velocity: AngleDirection { angle: 90; angleVariation: 80; magnitude: 70; magnitudeVariation: 40 }
                acceleration: PointDirection { y: 60 }
            }
            Wander {
                system: sea
                groups: ["drift"]
                xVariance: 26
                pace: 14
            }

            readonly property bool wide: surface.width >= 1280 && surface.width > surface.height
            readonly property real margin: Math.round(Math.min(surface.width, surface.height * 1.6) * 0.07)
            readonly property real floor: surface.height - Math.round(surface.height * 0.1)

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            BigClock {
                id: big
                x: surface.margin - big.inset
                y: surface.wide ? surface.floor - height : surface.height * 0.12
                now: clock.date
                format: Settings.timeFormat
                size: Math.round(Math.max(140, Math.min(260, surface.width * 0.13)))
                reveal: surface.show
            }

            Item {
                id: who
                width: Math.min(380, surface.width - surface.margin * 2)
                height: whoCol.implicitHeight
                x: (surface.wide ? surface.width - surface.margin - who.width : surface.margin) + who.shift
                // level with the foot of the digits
                y: surface.wide ? surface.floor - Math.round(big.size * 0.12) - height : big.y + big.height + 64
                opacity: surface.after(0.36, 0.4)
                transform: Translate { y: 24 * (1 - surface.after(0.36, 0.4)) }
                property real shift: 0

                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: who; property: "shift"; to: -12; duration: 45 }
                    NumberAnimation { target: who; property: "shift"; to: 9; duration: 70 }
                    NumberAnimation { target: who; property: "shift"; to: -5; duration: 70 }
                    NumberAnimation { target: who; property: "shift"; to: 0; duration: 60 }
                }

                Column {
                    id: whoCol
                    width: parent.width
                    spacing: 0

                    Row {
                        spacing: 10
                        Text {
                            anchors.baseline: parent.bottom
                            text: Session.username
                            font.family: Tokens.fontSans; font.pixelSize: 17; font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            color: Theme.text
                        }
                        Text {
                            anchors.baseline: parent.bottom
                            text: "locked at " + Qt.formatDateTime(scope.lockedAt, Settings.timeFormat)
                            font.family: Tokens.fontSans; font.pixelSize: 13
                            renderType: Text.NativeRendering
                            color: Theme.mute
                        }
                        height: 22
                    }
                    Item { width: 1; height: 10 }
                    PassField {
                        id: pass
                        width: parent.width
                        length: auth.entered.length
                        busy: auth.busy
                        failed: auth.failed
                        capsLock: auth.capsLock
                        onAccepted: auth.submit()
                    }
                    Text {
                        width: parent.width
                        topPadding: 10
                        height: 30
                        text: !lock.secure || auth.busy || auth.failed ? auth.hint : ""
                        font.family: Tokens.fontSans; font.pixelSize: 13
                        renderType: Text.NativeRendering
                        color: auth.failed ? Theme.alert : Theme.mute
                    }
                }
            }

            Row {
                id: music
                x: surface.margin
                y: surface.margin * 0.7
                spacing: 14
                visible: Settings.lock.media && Players.hasPlayer && Players.title !== ""
                opacity: surface.after(0.6, 0.4)

                Item {
                    width: 40; height: 40
                    Image {
                        id: cover
                        anchors.fill: parent
                        source: Players.artUrl
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 80; sourceSize.height: 80
                        asynchronous: true
                    }
                    Rectangle { anchors.fill: parent; color: Theme.surfaceSlate; visible: cover.status !== Image.Ready }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: Players.title
                        width: Math.min(implicitWidth, 300)
                        elide: Text.ElideRight
                        font.family: Tokens.fontSans; font.pixelSize: 14; font.weight: Font.Medium
                        renderType: Text.NativeRendering
                        color: Theme.text
                    }
                    Text {
                        text: Players.artist
                        width: Math.min(implicitWidth, 300)
                        elide: Text.ElideRight
                        font.family: Tokens.fontSans; font.pixelSize: 13
                        renderType: Text.NativeRendering
                        color: Theme.dim
                    }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 6
                    spacing: 14
                    Repeater {
                        model: [
                            { icon: Icons.previous, act: function() { Players.previous(); } },
                            { icon: Players.playing ? Icons.pause : Icons.play, act: function() { Players.playPause(); } },
                            { icon: Icons.next, act: function() { Players.next(); } }
                        ]
                        delegate: Icon {
                            required property var modelData
                            path: modelData.icon; size: 15
                            color: bh.hovered ? Theme.text : Theme.mute
                            HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor; margin: 6 }
                            TapHandler { onTapped: parent.modelData.act() }
                        }
                    }
                }
            }

            Row {
                id: facts
                anchors.right: parent.right
                anchors.rightMargin: surface.margin
                y: surface.margin * 0.7 + 10
                spacing: 26
                opacity: surface.after(0.66, 0.34)

                component Fact: Row {
                    property string icon: ""
                    property string label: ""
                    property color tint: Theme.dim
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter; path: parent.icon; size: 15; color: parent.tint }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.label
                        font.family: Tokens.fontSans; font.pixelSize: 14
                        renderType: Text.NativeRendering
                        color: Theme.dim
                    }
                }
                Fact {
                    visible: Settings.lock.weather && Weather.enabled && Weather.current !== null
                    icon: Weather.current ? Weather.icon(Weather.current.code, Weather.current.isDay) : ""
                    label: Weather.current ? Math.round(Weather.current.temp) + "°, " + Weather.describe(Weather.current.code).toLowerCase() : ""
                }
                Fact {
                    visible: Settings.lock.notifications && Notifs.unread > 0
                    icon: Icons.bell
                    label: Notifs.unread + (Notifs.unread === 1 ? " notification" : " notifications")
                }
                Fact {
                    visible: Battery.present
                    icon: Battery.icon
                    tint: Battery.percent <= 15 && !Battery.charging ? Theme.alert : Theme.dim
                    label: Battery.percent + "%"
                }
            }

            Connections {
                target: auth
                function onTyped() {
                    const at = pass.mapToItem(surface, pass.beadsX, pass.beadsY);
                    sparks.burst(3, at.x + (Math.random() - 0.5) * 120, at.y);
                    pulses.emit(at.x + (Math.random() - 0.5) * 140, at.y, 0.35);
                }
                function onRejected() {
                    const at = pass.mapToItem(surface, pass.beadsX, pass.beadsY);
                    for (let i = 0; i < 6; i++) scatter.burst(4, at.x + (i - 2.5) * 40, at.y);
                    pulses.emit(at.x, at.y, 1.4);
                    shake.restart();
                }
            }

            // keys land here and not in a TextInput, so nothing can be selected or copied
            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: function(event) { auth.key(event); }
            }
        }
    }
}
